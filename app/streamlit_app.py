"""App Streamlit: mostra as recomendações que o Job do Databricks gravou na tabela gold.

Lê o Lakehouse pelo SQL warehouse e chama o serving endpoint do modelo, com os secrets do
Databricks (Streamlit Cloud ou app/.streamlit/secrets.toml; modelo em secrets.toml.example).
"""

import time

import pandas as pd
import requests
import streamlit as st
from databricks import sql

st.set_page_config(page_title="Recomendação de notícias", page_icon="📰", layout="wide")

try:
    CFG = st.secrets["databricks"]
except Exception:  # sem secrets.toml ou sem a seção [databricks]
    st.error("Configure o Databricks em app/.streamlit/secrets.toml (modelo: secrets.toml.example).")
    st.stop()


def texto(titulo: str) -> str:
    return titulo.replace("$", r"\$")  # "R$ 10" não pode virar fórmula no Markdown


def cards(materias: pd.DataFrame) -> None:
    for linha in range(0, len(materias), 3):
        for coluna, m in zip(st.columns(3), materias.iloc[linha : linha + 3].itertuples()):
            with coluna, st.container(border=True):
                if m.image_url:
                    st.image(m.image_url, width="stretch")
                st.markdown(f"**[{texto(m.title)}]({m.url})**")
                st.caption(m.section)


@st.cache_data(ttl=600)
def carregar(consulta: str) -> pd.DataFrame:
    """Roda a consulta no SQL warehouse do Databricks."""
    with sql.connect(
        server_hostname=CFG["server_hostname"],
        http_path=CFG["http_path"],
        access_token=CFG["access_token"],
    ) as conn:
        return pd.read_sql(consulta.format(schema=CFG["schema"]), conn)


ENDPOINT = CFG["schema"].replace("_", "-")  # mesma regra do Terraform (infra/serving)


@st.cache_data(ttl=600)  # 1 chamada por pedido a cada 10 min (o Streamlit roda todas as abas a cada clique)
def recomendar_online(user_id: str, lidas: str = "") -> tuple[pd.DataFrame, float]:
    """Chama o serving endpoint (@champion): o top-10 é calculado na hora. Devolve também os segundos.

    lidas vazio = leitor conhecido (user_id); lidas = "url1,url2" = perfil montado na hora.
    """
    inicio = time.perf_counter()
    resposta = requests.post(
        f"https://{CFG['server_hostname']}/serving-endpoints/{ENDPOINT}/invocations",
        headers={"Authorization": f"Bearer {CFG['access_token']}"},
        json={"dataframe_records": [{"user_id": user_id, "lidas": lidas}]},
        timeout=15,  # parado (scale to zero), o endpoint demora a acordar: avisa em vez de travar o app
    )
    resposta.raise_for_status()
    return pd.DataFrame(resposta.json()["predictions"]), time.perf_counter() - inicio


def mostrar_online(user_id: str, lidas: str = "", n: int = 10) -> None:
    try:
        online, segundos = recomendar_online(user_id, lidas)
    except Exception as erro:  # endpoint não criado ou acordando (scale to zero); erro não vai p/ cache
        st.warning(f"O endpoint não respondeu ({type(erro).__name__}: {str(erro)[:200]}). "
                   "Ele já foi criado? Parado, ele leva alguns minutos para acordar: troque de aba e volte.")
    else:
        st.caption(f"{segundos:.1f} s na chamada ao endpoint - {len(online)} recomendações")
        cards(online.sort_values("rank").head(n).merge(materias, on="url"))


S = "workspace.{schema}"
usuarios = carregar(f"SELECT * FROM {S}.silver_users")
recs = carregar(f"SELECT * FROM {S}.gold_recommendations")
historico = carregar(
    f"SELECT c.*, a.title, a.section FROM {S}.silver_clicks c JOIN {S}.bronze_articles a USING (url)"
)
metricas = carregar(f"SELECT * FROM {S}.model_metrics")
materias = carregar(f"SELECT url, title, section, image_url, published_at FROM {S}.bronze_articles")
similares = carregar(f"SELECT lida, rank, url FROM {S}.gold_similares")  # vizinhos de cada matéria
recentes = materias.sort_values("published_at", ascending=False)
titulos = dict(zip(recentes["url"], recentes["title"]))  # para escolher as matérias do perfil

st.title("📰 Recomendação de notícias")
st.caption("Matérias reais do O Globo - leitores e cliques sintéticos - modelo treinado no Databricks")
st.caption(f"Dados: Lakehouse (workspace.{CFG['schema']})")

aba_recs, aba_online, aba_perfil, aba_perfil_online, aba_modelo = st.tabs([
    "Recomendações (Tabela Gold)", "Recomendações (Serving Endpoints)",
    "Monte seu perfil (Tabela Gold)", "Monte seu perfil (Serving Endpoints)", "Modelo",
])

with aba_recs:
    rotulos = {u.user_id: f"{u.user_id} - {u.persona}" for u in usuarios.itertuples()}
    usuario = st.selectbox("Leitor", sorted(set(recs["user_id"])), format_func=rotulos.get)
    esquerda, direita = st.columns([1, 2], gap="large")

    with esquerda:
        st.subheader("Leu")
        lidas = historico[historico["user_id"] == usuario].sort_values("event_ts", ascending=False)
        st.bar_chart(lidas["section"].value_counts(), horizontal=True, height=200)
        for m in lidas.head(8).itertuples():
            st.markdown(f"- [{texto(m.title)}]({m.url}) - `{m.section}`")

    with direita:
        st.subheader("Recomendado")
        top = recs[recs["user_id"] == usuario].sort_values("rank")
        st.caption(f"modelo @champion versão {top['model_version'].iloc[0]}")
        cards(top)

with aba_online:
    st.caption(f"Mesmo modelo @champion, calculado na hora pelo serving endpoint `{ENDPOINT}` "
               "(a aba Tabela Gold mostra o que o Job pré-calculou).")
    leitor = st.selectbox("Leitor", sorted(set(recs["user_id"])), format_func=rotulos.get, key="online")
    mostrar_online(leitor)

with aba_perfil:
    st.caption("Leitor novo (sem cliques), em batch: o Job pré-calculou os vizinhos de cada matéria "
               "(gold_similares) com o @champion; aqui somamos os votos dos vizinhos das que você marcou.")
    lidas = st.multiselect("Matérias que você leu", list(titulos), format_func=titulos.get, key="perfil")
    if lidas:
        votos = similares[similares["lida"].isin(lidas) & ~similares["url"].isin(lidas)]
        votos = votos.assign(voto=1 / votos["rank"]).groupby("url", as_index=False)["voto"].sum()
        cards(votos.nlargest(9, "voto").merge(materias, on="url"))  # 1º vizinho vale 1, o 2º 1/2...

with aba_perfil_online:
    st.caption(f"Leitor novo (sem cliques), online: o serving endpoint `{ENDPOINT}` pontua o seu perfil "
               "inteiro na hora (exato; a aba Tabela Gold é uma aproximação pré-calculada).")
    lidas = st.multiselect("Matérias que você leu", list(titulos), format_func=titulos.get, key="online2")
    if lidas:
        mostrar_online("perfil", ",".join(lidas), n=9)

with aba_modelo:
    st.subheader("Treinos registrados (tabela model_metrics)")
    st.dataframe(metricas.sort_values("avaliado_em", ascending=False), hide_index=True)
    st.caption("O vencedor só vira @champion se chegaram matérias novas (ou o contrato do modelo mudou) "
               "e ele supera a popularidade na prova de hoje.")

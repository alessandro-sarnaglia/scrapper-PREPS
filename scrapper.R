library(httr2)
library(rvest)
library(dplyr)
library(readr)
library(stringr)

# ---------------------------------------------------------
# 0. Configurações de Fuso Horário e Pastas
# ---------------------------------------------------------
# Garante que o horário registrado seja o de Brasília (UTC-3),
# mesmo rodando em servidores internacionais (GitHub Actions)
agora_br <- as.POSIXlt(Sys.time(), tz = "America/Sao_Paulo")
dt_extr  <- format(agora_br, format = "%Y-%m-%d")
hr_extr  <- format(agora_br, format = "%H:%M:%S")

# Pasta para organizar os arquivos diários
pasta_dados <- "dados"
if (!dir.exists(pasta_dados)) {
  dir.create(pasta_dados, recursive = TRUE)
}

# ---------------------------------------------------------
# 1. Requisição HTTP
# ---------------------------------------------------------
url_preps <- "https://www.preps.gov.br/web/index.php/embarcacao_consulta/list/?banner=true"

message(paste0("[", hr_extr, "] Conectando ao PREPS..."))

resp <- request(url_preps) |>
  req_headers(
    `User-Agent` = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"
  ) |>
  req_options(ssl_verifypeer = 0) |>       # Contorna validação da cadeia ICP-Brasil
  req_retry(max_tries = 3, backoff = ~ 5) |> # Tenta até 3 vezes em caso de oscilação
  req_perform()

# ---------------------------------------------------------
# 2. Parsing e Transformação dos Dados
# ---------------------------------------------------------
tabelas <- resp |>
  resp_body_html(encoding = "UTF-8") |>
  html_table()

# Extrai a tabela principal
df_embarcacoes <- tabelas[[1]] |>
  mutate(UF = gsub(".*-", "", `Inscrição MB`))

# Limpeza e adição de metadados de auditoria
df_embarcacoes <- df_embarcacoes |>
  rename_with(~ str_squish(.x)) |>
  mutate(
    across(where(is.character), str_trim),
    `Dia de Extração` = dt_extr,
    `Hora de Extração` = hr_extr
  )

# ---------------------------------------------------------
# 3. Exportação para CSV
# ---------------------------------------------------------
caminho_arquivo <- file.path(pasta_dados, paste0("embarcacoes_PREPS_", dt_extr, ".csv"))

write_excel_csv2(
  x = df_embarcacoes,
  file = caminho_arquivo
)

message(paste("Sucesso! Extraídas", nrow(df_embarcacoes), "linhas. Salvo em:", caminho_arquivo))

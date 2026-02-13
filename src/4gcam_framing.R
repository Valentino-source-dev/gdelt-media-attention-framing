
#GCAM Framing Analysis

suppressPackageStartupMessages({
  library(data.table)
  library(stringr)
  library(ggplot2)
})

cat("\n=== STEP 4: GCAM FRAMING ANALYSIS ===\n")

base_dir <- "/Users/valentino.virlan/Desktop/project/data"
input_file <- file.path(base_dir, "processed/gdelt_gkg.csv")
output_dir <- file.path(base_dir, "processed")

gkg <- fread(input_file)

# Mantener solo filas con GCAM disponible
gkg <- gkg[!is.na(gcam) & gcam != ""]

cat(sprintf("Documentos con GCAM: %d\n", nrow(gkg)))

#Parser GCAM
parse_gcam <- function(x) {
  parts <- str_split(x, ",")[[1]]
  parts <- parts[str_detect(parts, ".+:.+")]
  
  if (length(parts) == 0) return(NULL)
  
  data.table(
    gcam_code = str_extract(parts, "^[^:]+"),
    value     = as.numeric(str_extract(parts, "(?<=:)[0-9.+-eE]+"))
  )
}

cat("Parsing GCAM...\n")

gcam_long <- rbindlist(lapply(seq_len(nrow(gkg)), function(i) {
  dt <- parse_gcam(gkg$gcam[i])
  if (is.null(dt)) return(NULL)
  
  dt[, event  := gkg$event[i]]
  dt[, date   := gkg$date[i]]
  dt[, domain := gkg$domain[i]]
  
  dt
}), fill = TRUE)

cat(sprintf("Tokens GCAM totales: %d\n", nrow(gcam_long)))

cat("Agregando GCAM por día y evento...\n")

gcam_daily <- gcam_long[
  , .(mean_value = mean(value, na.rm = TRUE)),
  by = .(event, date, gcam_code)
]

cat("Normalizando señales GCAM...\n")

gcam_daily[
  , z_score := (mean_value - mean(mean_value)) / sd(mean_value),
  by = .(event, gcam_code)
]

cat("Agregando atención mediática por evento y día...\n")
men_daily <- fread(
  file.path(base_dir, "processed/gdelt_mentions_daily.csv")
)
men_event_daily <- men_daily[
  , .(mentions = sum(mentions, na.rm = TRUE)),
  by = .(event, date)
]

cat("Integrando GCAM con atención mediática (nivel evento-día)...\n")

gcam_with_attention <- merge(
  gcam_daily,
  men_event_daily,
  by = c("event", "date"),
  all.x = TRUE
)

gcam_with_attention[is.na(mentions), mentions := 0]


#save
fwrite(
  gcam_with_attention,
  file.path(output_dir, "gcam_framing_daily.csv")
)

cat("\n✓ GCAM framing dataset guardado\n")
cat("=== STEP 4 COMPLETADO ===\n")
gcam_variance <- gcam_with_attention[
  , .(var_z = sd(z_score, na.rm = TRUE)),
  by = .(event, gcam_code)
]
top_gcam <- gcam_variance[
  order(-var_z),
  head(gcam_code, 5)
] |> unique()


#gcam attention daily
ggplot(
  gcam_with_attention[gcam_code %in% top_gcam],
  aes(x = date)
) +
  geom_line(
    aes(y = z_score, color = gcam_code),
    linewidth = 1
  ) +
  geom_line(
    aes(y = scale(mentions)),
    linetype = "dashed",
    linewidth = 1,
    color = "black"
  ) +
  facet_wrap(~ event, scales = "free_x") +
  labs(
    title = "Evolución temporal del framing semántico y la atención mediática",
    subtitle = "Frames GCAM (líneas de color) y atención mediática normalizada (línea discontinua)",
    x = "Fecha",
    y = "Escala normalizada (z-score)",
    color = "Frame GCAM"
  ) +
  theme_minimal(base_size = 14) +
  theme(
    strip.text = element_text(face = "bold"),
    legend.position = "bottom"
  )


#top gcam nel tempos
top_gcam <- gcam_with_attention[
  , .(mean_abs = mean(abs(z_score), na.rm = TRUE)),
  by = gcam_code
][order(-mean_abs)][1:5]$gcam_code
gcam_with_attention[
  gcam_code %in% top_gcam
][
  , .(z = mean(z_score)), by = .(event, date, gcam_code)
] %>%
  ggplot(aes(x = date, y = z, color = gcam_code)) +
  geom_line() +
  facet_wrap(~ event, scales = "free_x") +
  labs(
    title = "Evolución temporal de los principales frames GCAM",
    y = "Intensidad GCAM (z-score)",
    x = "Fecha",
    color = "GCAM"
  ) +
  theme_minimal(base_size = 14)












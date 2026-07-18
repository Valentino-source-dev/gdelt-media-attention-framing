
suppressPackageStartupMessages({
  library(data.table)
  library(ggplot2)
})

cat("\n=== STEP 5: MEDIA ATTENTION ANALYSIS (MENTIONS) ===\n")


# Definición de rutas (base = raíz del proyecto)


base_dir <- "/Users/valentino.virlan/Desktop/project"

input_file <- file.path(base_dir, "data/processed/gdelt_mentions_daily.csv")
output_dir <- file.path(base_dir, "data/processed")


# Carga de datos de menciones diarias (Mentions)


cat("Cargando datos de mentions...\n")
men_daily <- fread(input_file)

cat("Menciones cargadas correctamente:\n")
print(head(men_daily))
cat(sprintf("Observaciones totales: %d\n", nrow(men_daily)))


# Agregación a nivel evento–día
# Se suman las menciones de todos los dominios


cat("Agregando mentions a nivel evento–día...\n")

mentions_event_daily <- men_daily[
  , .(total_mentions = sum(mentions, na.rm = TRUE)),
  by = .(event, date)
]

setorder(mentions_event_daily, event, date)

# Guardar dataset agregado
fwrite(
  mentions_event_daily,
  file.path(output_dir, "media_attention_event_daily.csv")
)

cat("Dataset agregado guardado: media_attention_event_daily.csv\n")


# GRÁFICO 1 — Evolución temporal de la atención mediática


cat("Generando gráfico de evolución temporal...\n")

p1 <- ggplot(
  mentions_event_daily,
  aes(x = date, y = total_mentions, color = event)
) +
  geom_line(linewidth = 1) +
  facet_wrap(~ event, scales = "free_x") +
  labs(
    title = "Evolución de la atención mediática en las fases iniciales de las crisis",
    subtitle = "Número diario de menciones en medios globales (GDELT)",
    x = "Fecha",
    y = "Menciones totales"
  ) +
  theme_minimal(base_size = 14) +
  theme(
    legend.position = "none",
    strip.text = element_text(face = "bold")
  )

ggsave(
  filename = file.path(output_dir, "media_attention_timeline.png"),
  plot = p1,
  width = 10,
  height = 6,
  dpi = 300
)

cat("Gráfico guardado: media_attention_timeline.png\n")


# GRÁFICO 2 — Intensidad media de la atención mediática


cat("Calculando intensidad media de atención por evento...\n")

attention_summary <- mentions_event_daily[
  , .(
    mean_mentions = mean(total_mentions),
    sd_mentions   = sd(total_mentions)
  ),
  by = event
]

# Ordenar eventos por atención media
attention_summary[
  , event := factor(event, levels = event[order(mean_mentions, decreasing = TRUE)])
]

p2 <- ggplot(
  attention_summary,
  aes(x = event, y = mean_mentions, fill = event)
) +
  geom_col(alpha = 0.8) +
  labs(
    title = "Intensidad media de la atención mediática por crisis",
    subtitle = "Promedio diario de menciones en medios globales (GDELT)",
    x = "Crisis",
    y = "Menciones diarias promedio"
  ) +
  theme_minimal(base_size = 14) +
  theme(
    legend.position = "none",
    plot.title = element_text(face = "bold")
  )

ggsave(
  filename = file.path(output_dir, "media_attention_mean_by_event.png"),
  plot = p2,
  width = 8,
  height = 6,
  dpi = 300
)
p1
p2
cat("Gráfico guardado: media_attention_mean_by_event.png\n")
cat("=== STEP 5 COMPLETADO ===\n")



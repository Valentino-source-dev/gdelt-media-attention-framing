
suppressPackageStartupMessages({
  library(data.table)
  library(ggplot2)
})

cat("\n=== STEP 4.5: CO-MOVIMIENTO GCAM Y ATENCIÓN MEDIÁTICA ===\n")

# Definición de rutas
base_dir <- "/Users/valentino.virlan/Desktop/project"
input_file <- file.path(base_dir, "data/processed/gcam_framing_daily.csv")
output_dir <- file.path(base_dir, "data/processed")

# Cargar datos GCAM + atención
cat("Cargando datos GCAM con atención mediática...\n")
gcam_att <- fread(input_file)

cat(sprintf("Observaciones totales: %d\n", nrow(gcam_att)))
print(head(gcam_att))

# Selección de los frames GCAM más relevantes
cat("Seleccionando frames GCAM más salientes...\n")

top_gcam <- gcam_att[
  , .(mean_abs = mean(abs(z_score), na.rm = TRUE)),
  by = gcam_code
][order(-mean_abs)][1:3]$gcam_code

print(top_gcam)

# Preparación de datos agregados
plot_data <- gcam_att[
  gcam_code %in% top_gcam,
  .(
    gcam_z = mean(z_score, na.rm = TRUE),
    mentions = mean(mentions, na.rm = TRUE)
  ),
  by = .(event, date, gcam_code)
]

# Normalización de la atención mediática
plot_data[
  , mentions_z := (mentions - mean(mentions)) / sd(mentions),
  by = event
]

# Gráfico de co-movimiento
cat("Generando gráfico de co-movimiento...\n")

p3 <- ggplot(plot_data, aes(x = date)) +
  geom_line(aes(y = gcam_z, color = gcam_code), linewidth = 1) +
  geom_line(
    aes(y = mentions_z),
    linewidth = 1,
    linetype = "dashed",
    color = "black"
  ) +
  facet_wrap(~ event, scales = "free_x") +
  labs(
    title = "Co-movimiento entre framing semántico y atención mediática",
    subtitle = "GCAM (líneas de color) vs atención mediática normalizada",
    x = "Fecha",
    y = "Escala normalizada (z-score)",
    color = "Frame GCAM"
  ) +
  theme_minimal(base_size = 14) +
  theme(
    strip.text = element_text(face = "bold"),
    legend.position = "bottom"
  )

p3

ggsave(
  filename = file.path(output_dir, "gcam_attention_comovement.png"),
  plot = p3,
  width = 11,
  height = 7,
  dpi = 300
)

cat("Gráfico guardado: gcam_attention_comovement.png\n")
cat("=== STEP 4.5 COMPLETADO ===\n")




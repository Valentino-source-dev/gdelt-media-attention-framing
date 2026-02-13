#ANÁLISIS DE REDES DE ATENCIÓN MEDIÁTICA (DOMINIOS)

suppressPackageStartupMessages({
  library(data.table)
  library(igraph)
})

cat("\n=== STEP 7: RED DE ATENCIÓN MEDIÁTICA ENTRE DOMINIOS ===\n")

base_dir   <- "/Users/valentino.virlan/Desktop/project/data"
input_file <- file.path(base_dir, "processed/gdelt_panel.csv")
output_dir <- file.path(base_dir, "processed")

cat("Cargando panel GDELT...\n")
panel <- fread(input_file)

# Nos quedamos con observaciones válidas
panel <- panel[
  !is.na(domain) & domain != "" &
    !is.na(event)  & !is.na(date)
]

cat(sprintf("Observaciones válidas: %d\n", nrow(panel)))

cat("Construyendo co-coberturas dominio–dominio...\n")

edges_list <- panel[
  ,
  {
    doms <- unique(domain)
    if (length(doms) < 2) return(NULL)
    
    pairs <- t(combn(doms, 2))
    
    data.table(
      from = pairs[,1],
      to   = pairs[,2]
    )
  },
  by = .(event, date)
]

cat(sprintf("Pares generados (sin agregar): %d\n", nrow(edges_list)))

edges <- edges_list[
  ,
  .N,
  by = .(from, to)
]

setnames(edges, "N", "weight")

cat(sprintf("Aristas agregadas: %d\n", nrow(edges)))

print(head(edges[order(-weight)], 10))

cat("Construyendo red de dominios...\n")

g <- graph_from_data_frame(
  edges[weight >= 5],   # filtro mínimo de robustez
  directed = FALSE
)

cat(sprintf("Nodos: %d | Aristas: %d\n", vcount(g), ecount(g)))

cat("Calculando métricas de red...\n")

deg <- degree(g, mode = "all")
bet <- betweenness(g, directed = FALSE, normalized = TRUE)
eig <- eigen_centrality(g)$vector

net_metrics <- data.table(
  domain = names(deg),
  degree = deg,
  betweenness = bet,
  eigenvector = eig
)[order(-degree)]

print(head(net_metrics, 10))

# Guardar métricas
fwrite(
  net_metrics,
  file.path(output_dir, "media_network_metrics.csv")
)

cat("Mostrando la red en RStudio...\n")

plot(
  g,
  vertex.size = log(degree(g) + 1) * 2,
  vertex.label.cex = 0.7,
  vertex.label.color = "black",
  edge.width = log(E(g)$weight + 1),
  main = "Red de Atención Mediática entre Dominios"
)




# Filtrar enlaces débiles (solo relaciones repetidas)
edges_strong <- edges[weight >= 5]

cat(sprintf(
  "Enlaces antes: %d | Enlaces después del filtro: %d\n",
  nrow(edges), nrow(edges_strong)
))
g_strong <- graph_from_data_frame(
  edges_strong,
  directed = FALSE
)
# Normalización de pesos
E(g_strong)$w_norm <- log1p(E(g_strong)$weight)

# Layout FR relajado (anti-colapso)
set.seed(123)
layout_relaxed <- layout_with_fr(
  g_strong,
  weights = E(g_strong)$w_norm,
  niter   = 3000
)

#anti-collasso
layout_relaxed <- layout_relaxed * 5


deg <- degree(g_strong)

plot(
  g_strong,
  layout = layout_relaxed,
  vertex.size  = log(deg + 1) * 2.5,
  vertex.color = colorRampPalette(c("lightblue","red"))(max(deg))[rank(deg)],
  vertex.label = NA,
  edge.width   = E(g_strong)$w_norm,
  main = "Red de Atención Mediática entre Dominios\n(Estructura global, enlaces fuertes)"
)
deg


#   TABLA DE MÉTRICAS DE RED

suppressPackageStartupMessages({
  library(data.table)
  library(igraph)
})

cat("\n=== STEP 7.X: MÉTRICAS DE CENTRALIDAD (TOP 10) ===\n")

# Calcular métricas
deg <- degree(g_strong, mode = "all")
bet <- betweenness(g_strong, directed = FALSE, normalized = TRUE)
eig <- eigen_centrality(g_strong)$vector

# Crear tabla
metrics_dt <- data.table(
  domain        = names(deg),
  degree        = as.numeric(deg),
  betweenness   = as.numeric(bet),
  eigenvector   = as.numeric(eig)
)

#   TOP 10 POR MÉTRICA

top_degree <- metrics_dt[order(-degree)][1:10]
top_bet    <- metrics_dt[order(-betweenness)][1:10]
top_eig    <- metrics_dt[order(-eigenvector)][1:10]

cat("\n--- TOP 10: DEGREE ---\n")
print(top_degree)

cat("\n--- TOP 10: BETWEENNESS ---\n")
print(top_bet)

cat("\n--- TOP 10: EIGENVECTOR ---\n")
print(top_eig)

g_core <- g_strong

# Calcular rango en el núcleo
deg_core <- degree(g_core)

# Ordena los vértices por grado y obtén los 20 primeros
top_vids <- V(g_core)[order(deg_core, decreasing = TRUE)][1:20]

# Subgraph top 20
g_core_top <- induced_subgraph(g_core, vids = top_vids)

# Layout
set.seed(321)
layout_top <- layout_with_fr(g_core_top, niter = 2000)
layout_top <- layout_top * 3

# Plot
plot(
  g_core_top,
  layout = layout_top,
  vertex.size = log(degree(g_core_top) + 1) * 6,
  vertex.color = "tomato",
  vertex.label.cex = 0.9,
  edge.width = log(E(g_core_top)$weight + 1),
  main = "Top 20 Dominios más Centrales\n(Core de Atención Mediática)"
)












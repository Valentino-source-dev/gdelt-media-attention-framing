library(data.table)

# Definición de rutas base

# Directorio base para los datos
base_dir <- "data"

# Directorio donde se guardarán los archivos descargados (datos brutos)
raw_dir  <- file.path(base_dir, "raw")

# Crear el directorio si no existe
if (!dir.exists(raw_dir)) dir.create(raw_dir, recursive = TRUE)

# Definición de ventanas temporales por evento


# Para cada evento se define una ventana temporal específica
windows <- list(
  ukraine   = seq.Date(as.Date("2022-02-24"), as.Date("2022-03-05"), by="day"),
  gaza      = seq.Date(as.Date("2023-10-07"), as.Date("2023-10-17"), by="day"),
  venezuela = seq.Date(as.Date("2024-12-25"), as.Date("2025-01-05"), by="day")
)


# Descarga del masterfilelist oficial de GDELT


# URL del archivo que contiene la lista completa de ficheros disponibles en GDELT
mfl <- "http://data.gdeltproject.org/gdeltv2/masterfilelist.txt"

# Ruta local donde se guarda el masterfilelist
tmp <- file.path(base_dir, "masterfilelist.txt")

# Descarga silenciosa del archivo
download.file(mfl, tmp, quiet = TRUE)

# Parseo del masterfilelist


# Leer todas las líneas del archivo
lines <- readLines(tmp)

# Función para extraer tamaño, hash y URL de cada línea
parse_line <- function(x) {
  p <- strsplit(x, "\\s+")[[1]]
  if (length(p) >= 3)
    data.frame(size = p[1], hash = p[2], url = p[3], stringsAsFactors = FALSE)
}

# Construcción de una tabla con todas las URLs disponibles
master <- rbindlist(lapply(lines, parse_line))

# Vector con todas las URLs de los ficheros GDELT
urls <- master$url


# Función de descarga segura


# Descarga un archivo y verifica que no esté vacío o corrupto
safe_get <- function(url, dest) {
  tryCatch({
    download.file(url, dest, mode = "wb", quiet = TRUE)
    if (file.exists(dest) && file.size(dest) > 0) return(TRUE)
    if (file.exists(dest)) unlink(dest)
    FALSE
  }, error = function(e) FALSE)
}

# Descarga de ficheros GKG y Mentions por evento y día


# Iteración sobre cada evento
for (event in names(windows)) {
  
  # Iteración sobre cada día de la ventana temporal
  for (d in windows[[event]]) {
    
    # Formato de fecha YYYYMMDD
    d_str <- format(d, "%Y%m%d")
    
    # Patrón para identificar archivos del día concreto
    pattern <- paste0(d_str, "[0-9]{6}")
    
    # Seleccionar los archivos correspondientes a ese día
    day <- grep(pattern, urls, value = TRUE)
    if (length(day) == 0) next
    
    # Seleccionar archivos Translation GKG y Translation Mentions
    gkg <- grep("translation\\.gkg\\.csv\\.zip$", day, value = TRUE, ignore.case = TRUE)
    men <- grep("translation\\.mentions\\.CSV\\.zip$", day, value = TRUE, ignore.case = TRUE)
    
    # Mantener solo un archivo por tipo y día
    wanted <- c(
      if (length(gkg) > 0) gkg[1] else NA,
      if (length(men) > 0) men[1] else NA
    )
    
    wanted <- wanted[!is.na(wanted)]
    
    # Descargar los archivos si no existen localmente
    for (u in wanted) {
      dest <- file.path(raw_dir, paste0(event, "_", basename(u)))
      if (!file.exists(dest)) safe_get(u, dest)
    }
  }
}

# El script no devuelve ningún objeto en el entorno
invisible(NULL)




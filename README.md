# GDELT Media Attention & Framing Analysis

This repository contains a full research pipeline for analyzing global media attention and semantic framing during major geopolitical crises using GDELT data.

The project adopts a **descriptive and reproducible research design**, focusing on media attention dynamics and linguistic framing rather than predictive modeling or causal inference.

## Research Focus
- Temporal evolution of media attention during geopolitical crises
- Semantic framing analysis using GCAM variables
- Cross-regional and cross-media comparisons
- NLP-based validation on high-attention news articles

## Data
The analysis relies on GDELT Global Knowledge Graph (GKG) and Mentions datasets.
Raw GDELT data are not included in the repository due to size constraints, but they can be reconstructed by running the download and preprocessing scripts provided in `src/`.

## Project Structure
```text
src/        # R scripts implementing the analysis pipeline
data/
  ├── raw/        # Raw GDELT data (not included)
  └── processed/  # Intermediate datasets used in the analysis
results/
  └── tables/     # Aggregated outputs and result tables
report/
  └── report.pdf  # Final research report

## Methodological Notes
- The project is explicitly **descriptive**
- No causal inference or sentiment classification is performed
- NLP techniques are used for exploration and qualitative validation only
- Methodological limitations are discussed in the report

## Report
The final research report is available in `report/report_untructured_data(2).pdf`.  
The document is written in **Spanish and Italian**, reflecting the academic context in which the project was developed.

## Reproducibility
All scripts are numbered to reflect the logical execution order of the pipeline.  
The repository is structured to allow full reproduction of the analysis, excluding raw data downloads.


#' Agrège les données Medic'AM sur les dimensions temporelle et produit
#'
#' @description
#' Effectue un regroupement flexible des volumes de boîtes remboursées issus de Medic'AM :
#' - Sur le plan temporel : conservation du mois, ou passage au trimestre, semestre ou année.
#' - Sur le plan produit : conservation de la granularité CIP13 + nom court, ou agrégation au niveau ATC.
#'
#' @param data `tibble` ou `data.frame`. La table produite par `parse_medicam_files()` 
#'   contenant les colonnes `cip13`, `nom_court`, `code_atc`, `classe_atc`, `annee`, `mois`, `nb_boite`.
#' @param freq `character(1)`. Niveau de réagrégation temporelle :
#'   - `"mois"` (défaut) : conserve le format AA-MM original.
#'   - `"trimestre"` : agrège par trimestre (ex: `"2023-Q1"`).
#'   - `"semestre"` : agrège par semestre (ex: `"2023-S1"`).
#'   - `"annee"` : agrège par année civile (ex: `"2023"`).
#' @param by_cip `logical(1)`. 
#'   - `TRUE` (défaut) : conserve le détail par `cip13` et `nom_court`.
#'   - `FALSE` : agrège toutes les présentations au niveau du `code_atc` et `classe_atc`.
#'
#' @return Un `tibble` regroupé et ordonné contenant la somme des boîtes (`nb_boite`).
#'
#' @importFrom dplyr %>% mutate summarize group_by arrange select all_of across
#' @importFrom stringr str_pad
#'
#' @export
aggregate_medicam <- function(data, 
                              freq = c("mois", "trimestre", "semestre", "annee"), 
                              by_cip = TRUE) {
  
  # Validation des arguments
  freq <- match.arg(freq)
  
  # 1. Traitement de la variable de période hors du pipe (if/else)
  annee_chr <- as.character(data$annee)
  mois_num  <- as.numeric(data$mois)
  
  periode_vec <- if (freq == "mois") {
    paste0(annee_chr, "-", str_pad(data$mois, width = 2, pad = "0"))
  } else if (freq == "trimestre") {
    paste0(annee_chr, "-Q", ceiling(mois_num / 3))
  } else if (freq == "semestre") {
    paste0(annee_chr, "-S", ceiling(mois_num / 6))
  } else if (freq == "annee") {
    annee_chr
  }
  
  # 2. Assignation de la nouvelle variable
  df_prepped <- data %>% 
    mutate(periode = periode_vec)
  
  # 3. Définition dynamique des variables de regroupement
  group_vars <- if (by_cip) {
    c("code_atc", "classe_atc", "cip13", "nom_court", "periode")
  } else {
    c("code_atc", "classe_atc", "periode")
  }
  
  # 4. Agrégation finale
  res <- df_prepped %>% 
    group_by(across(all_of(group_vars))) %>% 
    summarize(
      nb_boite = sum(nb_boite, na.rm = TRUE),
      .groups = "drop"
    ) %>% 
    arrange(code_atc, if (by_cip) cip13 else code_atc, periode)
  
  return(res)
}

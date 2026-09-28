library(tidyverse)
library(httr2)
liste_atc <- c(
  "N05AH04","N06AB06","N06AX16","N07CA04","C10AX13","S01CA01","L01BC02","H02AB06",
  "H02AB07","N06BA04","C03DA01","C03EA04","C07AB03","C07FB03","C09CA03","C09DB01","C09DA03","N03AA03","N03AG06",
  "N04BA02","N03AG01","N04BA03","J01CA04","J01CR02"
  )




list.files("R", pattern = "\\.R$", full.names = TRUE) %>% 
  walk(source)


parse_medicam_files <- function(folder_path = "data/medicam"){
  
  iteration_file <- list.files(path = folder_path,full.names = TRUE)
  
  result_medoc <- lapply(iteration_file, function(path_x) {
    # print(path_x)
    
    df_fun <- readxl::read_xls(path_x, sheet = 2) %>% 
      janitor::clean_names() %>% 
      mutate(
        # Formatage du CIP13 sur 13 caractères avec zéro initial si besoin
        cip13 = str_pad(as.character(cip13), width = 13, pad = "0")
      )
    
    # 1. On détermine la colonne présente AVANT de passer au pipe
    col_atc <- if ("code_atc" %in% names(df_fun)) "code_atc" else "code_6"
    col_classe <- if ("classe_atc" %in% names(df_fun)) "classe_atc" else "classe"
    
    res <- df_fun %>% 
      rename(code_atc = all_of(col_atc),
             classe_atc = all_of(col_classe),
      ) %>%
      # 2. Filtrage propre via la variable dynamique
      filter(code_atc %in% liste_atc) %>% 
      
      # 3. Sélection sécurisée des colonnes
      select(
        cip13, 
        nom_court, 
        code_atc,
        # produit,
        classe_atc,
        starts_with("nombre_de_boites_remboursees_")
      ) %>% 
      
      # 4. Pivotement au format long
      pivot_longer(
        cols = matches("^nombre_de_boites_remboursees_\\d{4}_\\d{2}$"),
        names_to = c("annee", "mois"),
        names_pattern = "^nombre_de_boites_remboursees_(\\d{4})_(\\d{2})$",
        values_to = "nb_boite"
      )
    
    return(res)
  }) %>% 
    bind_rows()
  return(result_medoc)
}



ref_cip <- GET_dose_bdd(rerun = TRUE, bdd_path = "data/fichier_intermediaire/base_dosage.csv")

# path_x <- iteration_file[1]#"data/M�dic'AM mensuel 2017 - 2eme semestre_tous r�gimes.xls"

result_medoc <- parse_medicam_files()





write.csv(result_medoc,"outpout/donne_detect_penurie_lola.csv")


# 1. Préparation des données (création d'une vraie date pour l'axe des x)
df_plot <- result_medoc %>% 
  mutate(
    date = ym(paste(annee, mois, sep = "-")),
    nb_boite = as.numeric(nb_boite)
  ) %>% 
  # Agrégation : somme des boîtes par code ATC, nom de produit et date
  group_by(code_atc, classe_atc, date) %>% 
  summarise(total_boites = sum(nb_boite, na.rm = TRUE), .groups = "drop")
# 2. Création du dossier de destination s'il n'existe pas
output_dir <- "outpout/plots_atc"
if (!dir.exists(output_dir)) dir.create(output_dir)

# 3. Génération et sauvegarde des graphiques en PDF
liste_atc %>% 
  walk(function(atc_code) {
    
    # Filtrage sur le code ATC courant
    df_sub <- df_plot %>% filter(code_atc == atc_code)
    
    if (nrow(df_sub) == 0) return(NULL)
    
    # Récupération du/des nom(s) de produit associés à cet ATC pour le titre
    nom_produit <- paste(unique(df_sub$classe_atc), collapse = " / ")
    
    # Création du graphique
    p <- ggplot(df_sub, aes(x = date, y = total_boites)) +
      geom_line(color = "#2b5c8f", linewidth = 1) +
      geom_point(color = "#2b5c8f", size = 2) +
      scale_x_date(date_labels = "%b %Y", date_breaks = "3 months") +
      scale_y_continuous(labels = scales::label_number(big.mark = " ")) +
      labs(
        title = paste("Évolution —", nom_produit),
        subtitle = paste("Code ATC :", atc_code),
        x = "Date",
        y = "Nombre total de boîtes remboursées"
      ) +
      theme_minimal() +
      theme(
        plot.title = element_text(face = "bold", size = 13),
        axis.text.x = element_text(angle = 45, hjust = 1)
      )
    
    # Sauvegarde en PDF
    file_path <- file.path(output_dir, paste0("plot_", atc_code, ".pdf"))
    ggsave(
      filename = file_path, 
      plot = p, 
      width = 9, 
      height = 5, 
      device = "pdf"
    )
  })

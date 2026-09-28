# 📦 MedicAM Analysis Pipeline

Ce projet R permet d'importer, de nettoyer, d'enrichir et d'agréger les données mensuelles de délivrance de médicaments en ville issues de la base **Medic'AM** (Assurance Maladie).

---

## 🛠️ Structure du projet

```text
.
├── R/                          # Fonctions R du pipeline
│   ├── parse_medicam_files.R   # Importation et mise au format long des fichiers Medic'AM
│   ├── GET_dose_bdd.R          # Récupération et mise en cache du référentiel BDPM
│   ├── add_dosage_info.R       # Enrichissement / Calcul des dosages (WIP)
│   └── aggregate_medicam.R     # Agrégation temporelle et par produit
├── data/
│   ├── medicam/                # Fichiers .xls d'origine téléchargés depuis Ameli
│   └── fichier_intermediaire/  # Fichiers mis en cache (BDPM local)
└── main.R                      # Script principal d'exécution

```

---

## 🚀 Utilisation rapide

```r
library(tidyverse)
library(httr2)

# 1. Chargement de l'ensemble des fonctions du dossier R/
list.files("R", pattern = "\\.R$", full.names = TRUE) %>% 
  walk(source)

# 2. Définition des codes ATC d'intérêt
liste_atc <- c(
  "N05AH04", "N06AB06", "N06AX16", "N07CA04", "C10AX13", "S01CA01", "L01BC02", "H02AB06",
  "H02AB07", "N06BA04", "C03DA01", "C03EA04", "C07AB03", "C07FB03", "C09CA03", "C09DB01", 
  "C09DA03", "N03AA03", "N03AG06", "N04BA02", "N03AG01", "N04BA03", "J01CA04", "J01CR02"
)

# 3. Récupération / Mise à jour du référentiel des dosages (API BDPM)
ref_cip <- GET_dose_bdd(
  rerun = TRUE, 
  bdd_path = "data/fichier_intermediaire/base_dosage.csv"
)

# 4. Importation et structuration des données Medic'AM (.xls)
result_medoc <- parse_medicam_files(
  folder_path = "data/medicam", 
  liste_atc = liste_atc
)

# 5. Enrichissement des données avec le dosage (⚠️ Work in Progress)
result_medoc_dosage <- add_dosage_info(
  data = result_medoc, 
  ref_cip = ref_cip,
  strict = FALSE # Passer à TRUE pour forcer l'arrêt en cas de valeurs non parsées
)

# 6. Agrégation des résultats (ex. trimestriel par CIP)
res_trimestre_cip <- aggregate_medicam(
  data = result_medoc, 
  freq = "trimestre", 
  by_cip = TRUE
)

```

---

## ⚙️ Détail des fonctions

### 1. `parse_medicam_files(folder_path = "data/medicam", liste_atc)`

* **Rôle :** Lit les fichiers Excel `.xls` Medic'AM, filtre sur la liste d'ATC cibles, harmonise la dénomination des colonnes et pivote la table au format long.
* **Sortie :** `tibble` avec les colonnes `cip13`, `nom_court`, `code_atc`, `classe_atc`, `annee`, `mois`, `nb_boite`.

### 2. `GET_dose_bdd(rerun = TRUE, bdd_path = "...")`

* **Rôle :** Interroge l'API de la Base de Données Publique des Médicaments (BDPM) pour constituer une table de correspondance `CIP13` ↔ `composants / dosages / nombre d'unités`. Maintient un cache CSV local.

### 3. `add_dosage_info(data, ref_cip, strict = TRUE)` 🚧 **[Work In Progress]**

> **Note :** Cette fonction est en cours de développement. Elle vise à automatiser la conversion des boîtes remboursées en quantités de principe actif dispensées.

* **Rôle :**
* Effectue la jointure sur le `CIP13` avec la BDPM pour extraire le dosage, l'unité et le nombre d'unités par boîte.
* Applique une stratégie de **fallback par Regex** sur le `nom_court` pour compléter les présentations absentes de la BDPM.
* Calcule la dose par boîte (`dose_per_box`) et la dose totale dispensée (`total_dispensed_dose`).


* **Limitations connues (WIP) :**
* Le parsing des associations de principes actifs (ex: `80 MG/12.5 MG`) et des formes liquides (`MG/ML`) repose sur des règles de somme et d'extraction Regex en cours d'ajustement.
* Si `strict = TRUE`, la fonction interrompt l'exécution en affichant la liste des `CIP13` contenant des `NA` sur les variables de dosage.



### 4. `aggregate_medicam(data, freq = "mois", by_cip = TRUE)`

* **Rôle :** Permet la réagrégation flexible des données selon deux axes :
* **Temporel (`freq`) :** `"mois"`, `"trimestre"`, `"semestre"` ou `"annee"`.
* **Produit (`by_cip`) :** Conservation du détail par présentation (`cip13` / `nom_court`) si `TRUE`, ou regroupement à la classe ATC (`code_atc` / `classe_atc`) si `FALSE`.



---

## 📋 Prérequis

```r
install.packages(c("tidyverse", "httr2", "readxl", "janitor", "jsonlite"))

```

```


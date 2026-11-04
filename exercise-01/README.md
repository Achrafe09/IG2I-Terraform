# Exercice 1 : Comprendre le state Terraform avec le provider Random

## Objectifs

- Découvrir la syntaxe de base de Terraform
- Comprendre le concept de **state** dans Terraform
- Observer comment Terraform gère les ressources entre différentes exécutions
- Manipuler un provider simple qui ne nécessite pas de credentials cloud

## Structure

```
exercise-01/
├── main.tf
└── README.md
```

---

## Partie 1 : Configuration

### main.tf

```hcl
terraform {
  required_providers {
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

# Nom de serveur : 2 mots séparés par un tiret
resource "random_pet" "server_name" {
  length    = 2
  separator = "-"
}

# Port entre 8000 et 8999
resource "random_integer" "port" {
  min = 8000
  max = 8999
}

# Mot de passe de 16 caractères avec caractères spéciaux
resource "random_password" "password" {
  length  = 16
  special = true
}

# Identifiant de session
resource "random_uuid" "session_id" {}

output "server_name" {
  value = random_pet.server_name.id
}

output "port" {
  value = random_integer.port.result
}

output "password" {
  value     = random_password.password.result
  sensitive = true
}

output "session_id" {
  value = random_uuid.session_id.result
}
```

L'output `password` doit être marqué `sensitive = true`, sinon Terraform refuse de l'afficher et renvoie une erreur.

---

## Partie 2 : Workflow Terraform

### `terraform init`

**Fichiers créés :**
- `.terraform/` : contient le binaire du provider `hashicorp/random` téléchargé depuis le Terraform Registry
- `.terraform.lock.hcl` : verrouille la version exacte du provider installée (et ses checksums) pour que tout le monde utilise la même

**Ce que fait la commande :** elle prépare le répertoire de travail. Elle lit le bloc `required_providers`, télécharge les providers correspondants, initialise le backend (ici local, donc le state sera stocké dans `terraform.tfstate`) et installe les éventuels modules. C'est la première commande à lancer dans un nouveau projet ou après un changement de provider.

### `terraform plan`

**Symbole `+` :** la ressource va être **créée**.

**Nombre de ressources :** 4 (`random_pet`, `random_integer`, `random_password`, `random_uuid`).

```
Plan: 4 to add, 0 to change, 0 to destroy.
```

Les valeurs apparaissent comme `(known after apply)` car elles ne sont générées qu'au moment de l'apply.

### `terraform apply`

Après confirmation avec `yes`, Terraform crée les 4 ressources et affiche les outputs :

```
Apply complete! Resources: 4 added, 0 changed, 0 destroyed.

Outputs:

password    = <sensitive>
port        = 8xxx
server_name = "xxxx-xxxx"
session_id  = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
```

### Le fichier `terraform.tfstate`

**Format :** JSON.

**Contenu :**
- `version` : version du format de state
- `terraform_version` : version de Terraform utilisée
- `serial` : numéro incrémenté à chaque modification du state
- `lineage` : identifiant unique du state, fixé à sa création
- `outputs` : valeurs des outputs, avec leur type et le flag `sensitive`
- `resources` : la liste des ressources gérées, avec pour chacune son type, son nom, son provider et ses attributs (`instances[].attributes`)

**Retrouve-t-on les valeurs générées ?** Oui, toutes. Y compris le mot de passe, **en clair**. Le flag `sensitive` masque la valeur dans l'affichage du terminal, mais pas dans le state. C'est pour ça que le state doit être traité comme un fichier sensible.

---

## Partie 3 : Immutabilité du state

### Deuxième `terraform plan`

**Constat :**

```
No changes. Your infrastructure matches the configuration.
```

**Pourquoi :** Terraform compare la configuration (`main.tf`) avec le state. Les 4 ressources existent déjà dans le state avec des attributs qui correspondent à la configuration, donc il n'y a aucune différence et rien à faire. Les valeurs aléatoires ne sont générées qu'une seule fois, à la création de la ressource, puis stockées dans le state.

### Deuxième `terraform apply`

**Les valeurs ont-elles changé ?** Non.

**Pourquoi :** pour Terraform, une valeur aléatoire est une ressource comme une autre. Une fois créée, elle existe dans le state et Terraform ne la recrée que si sa configuration change ou si on le force. Terraform est déclaratif et idempotent : appliquer plusieurs fois la même configuration donne le même résultat.

### `terraform output`

Affiche les outputs en lisant le state, sans rien recalculer ni réappliquer :

```bash
terraform output              # tous les outputs, le password reste masqué
terraform output password     # affiche la valeur du password
terraform output -raw password  # affiche la valeur sans guillemets
```

---

## Partie 4 : Forcer la régénération

### `terraform taint random_pet.server_name`

La commande marque la ressource comme "tainted" (abîmée) dans le state. Au prochain apply, Terraform la détruira et la recréera.

Note : `taint` est dépréciée depuis Terraform 0.15.2. L'équivalent recommandé est :

```bash
terraform apply -replace="random_pet.server_name"
```

L'avantage de `-replace` est qu'on voit le plan avant que le state soit modifié.

### `terraform plan`

**Symboles `-/+` :** la ressource va être **détruite puis recréée** (remplacement).

```
# random_pet.server_name is tainted, so must be replaced
-/+ resource "random_pet" "server_name" {

Plan: 1 to add, 0 to change, 1 to destroy.
```

**Ce qui va se passer :** l'ancien `random_pet` est supprimé du state et un nouveau est généré avec un nouveau nom.

### `terraform apply`

- **Le nom du serveur a-t-il changé ?** Oui, un nouveau nom a été généré.
- **Les autres valeurs ont-elles changé ?** Non. Seule la ressource marquée est remplacée, le port, le password et l'UUID restent identiques car rien ne les concerne.

---

## Partie 5 : Modifier la configuration

Passage de `length = 2` à `length = 3` :

```hcl
resource "random_pet" "server_name" {
  length    = 3
  separator = "-"
}
```

### `terraform plan`

```
-/+ resource "random_pet" "server_name" {
      ~ id     = "xxxx-xxxx" -> (known after apply)
      ~ length = 2 -> 3 # forces replacement

Plan: 1 to add, 0 to change, 1 to destroy.
```

**Observation :** Terraform ne peut pas modifier la ressource "sur place" (in-place, symbole `~`). L'attribut `length` est marqué `forces replacement` : changer cet argument impose de détruire la ressource et d'en créer une nouvelle. C'est logique, un nom déjà généré ne peut pas "gagner" un mot.

### `terraform apply`

Le nom du serveur est remplacé par un nouveau nom de 3 mots (ex : `xxxx-xxxx-xxxx`). Les autres ressources ne bougent pas.

---

## Partie 6 : Destruction

### `terraform destroy`

Le plan affiche les 4 ressources avec le symbole `-` (suppression) :

```
Plan: 0 to add, 0 to change, 4 to destroy.
...
Destroy complete! Resources: 4 destroyed.
```

### Le fichier `terraform.tfstate` après destruction

**Est-il vide ?** Non, le fichier existe toujours.

**Contenu :** les métadonnées sont conservées (`version`, `terraform_version`, `lineage`, `serial` incrémenté), mais `resources` est une liste vide `[]` et `outputs` est vide `{}`. Terraform garde le state pour garder la trace du projet et de son historique (`lineage` + `serial`).

Le fichier `terraform.tfstate.backup` contient la version précédente du state, avec les anciennes valeurs (dont le mot de passe en clair).

---

## Questions de réflexion

### 1. Pourquoi le state est-il important ?

Le state est la "mémoire" de Terraform. Il fait le lien entre les ressources déclarées dans le code et les ressources réellement créées. Il permet de :

- savoir ce qui existe déjà et ce qui doit être créé, modifié ou supprimé
- calculer le diff entre la configuration et la réalité
- connaître l'ordre des dépendances, y compris pour la destruction
- stocker les attributs générés (ID, IP, valeurs aléatoires) réutilisés par d'autres ressources
- accélérer les plans (pas besoin d'interroger toute l'infrastructure)

**Sans state :** Terraform ne saurait pas ce qu'il a déjà créé. À chaque apply, il recréerait tout (doublons de serveurs, nouveaux mots de passe), il ne pourrait pas supprimer une ressource retirée du code puisqu'il ne saurait pas qu'elle existe, et `terraform destroy` ne servirait à rien.

### 2. Immutabilité des valeurs aléatoires

**Pourquoi c'est important :** une infrastructure doit être stable et reproductible. Si les valeurs changeaient à chaque apply, chaque exécution modifierait l'infrastructure, même sans changement de code. On perdrait l'idempotence, qui est le principe de base de Terraform.

**Cas réels où ce serait un problème :**
- **Mot de passe de base de données** : un nouveau mot de passe à chaque apply couperait toutes les applications connectées
- **Nom de serveur ou de bucket** : un nouveau nom entraînerait la destruction et la recréation de la ressource, donc une perte de données ou une coupure de service
- **Port** : les règles de firewall, les load balancers et les clients configurés sur l'ancien port ne fonctionneraient plus
- **Identifiant de session ou clé de chiffrement** : toutes les sessions seraient invalidées, les données chiffrées deviendraient illisibles

### 3. State en équipe

**Peut-on le partager sur Git ?** Techniquement oui, mais il ne faut pas. Il faut l'ajouter au `.gitignore` :

```
.terraform/
*.tfstate
*.tfstate.*
```

Le fichier `.terraform.lock.hcl`, lui, doit être commité.

**Problèmes en équipe :**
- **Secrets en clair** : le state contient les mots de passe, clés et tokens. Les mettre sur Git les expose à toute personne ayant accès au dépôt et à l'historique
- **Conflits** : deux personnes qui font un apply en parallèle modifient le state chacune de leur côté. Les merges Git sur un fichier JSON comme celui-ci sont risqués et peuvent le corrompre
- **Pas de verrouillage** : rien n'empêche deux apply simultanés sur la même infrastructure
- **State obsolète** : si quelqu'un oublie de pull, il travaille sur un state périmé et Terraform peut recréer ou supprimer des ressources par erreur

**Solution :** un **remote state** (backend S3 + DynamoDB, Azure Storage, GCS, Terraform Cloud, GitLab...) qui centralise le state, le chiffre et gère le **verrouillage** (state locking) pour éviter les exécutions concurrentes.

### 4. Comparaison avec Ansible

| | Terraform | Ansible |
|---|---|---|
| Approche | Déclarative : on décrit l'état final | Plutôt procédurale : on décrit une suite de tâches |
| State | Fichier de state qui mémorise ce qui a été créé | Pas de state : interroge la machine cible à chaque exécution |
| Calcul du diff | Compare code et state, affiche un plan avant d'agir | Chaque module vérifie l'état réel et agit si besoin (`changed` / `ok`) |
| Suppression | Retirer une ressource du code la supprime | Retirer une tâche ne supprime rien, il faut écrire une tâche avec `state: absent` |
| Usage principal | Provisionner l'infrastructure (VM, réseau, cloud) | Configurer les machines (paquets, fichiers, services) |

**Avantages de Terraform :**
- plan clair et prévisible avant toute modification
- gestion complète du cycle de vie, y compris la suppression
- gestion automatique des dépendances entre ressources

**Inconvénients de Terraform :**
- le state doit être stocké, sécurisé, sauvegardé et verrouillé
- risque de dérive (drift) si quelqu'un modifie l'infrastructure à la main en dehors de Terraform
- un state corrompu ou perdu est difficile à récupérer

**Avantages d'Ansible :**
- rien à stocker ni à synchroniser, la source de vérité est la machine elle-même
- simple à prendre en main, sans agent sur les cibles (SSH)

**Inconvénients d'Ansible :**
- ne sait pas ce qu'il a créé, donc pas de nettoyage automatique
- pas de vrai plan global avant exécution (le mode `--check` est limité)
- moins adapté à la création d'infrastructure cloud

Les deux sont complémentaires : Terraform pour créer l'infrastructure, Ansible pour configurer ce qui tourne dessus.

---

## Pour aller plus loin

### Autres ressources du provider random

```hcl
# Chaîne aléatoire (non sensible, visible dans les logs)
resource "random_string" "suffix" {
  length  = 8
  upper   = false
  special = false
}

# Mélange une liste
resource "random_shuffle" "az" {
  input        = ["eu-west-1a", "eu-west-1b", "eu-west-1c"]
  result_count = 2
}

# Identifiant aléatoire, disponible en hex, base64, décimal
resource "random_id" "bucket" {
  byte_length = 4
}
```

- `random_string` : comme `random_password` mais la valeur n'est pas sensible. Pratique pour des suffixes de noms (ex : nom de bucket unique)
- `random_shuffle` : choisit aléatoirement un ou plusieurs éléments dans une liste (ex : répartir des ressources sur des zones)
- `random_id` : génère des octets aléatoires exposés sous plusieurs formats (`hex`, `b64_url`, `dec`)

### Remote state et backends

Un **backend** définit où Terraform stocke son state. Par défaut c'est le backend `local` (fichier `terraform.tfstate`). En équipe, on utilise un backend distant :

```hcl
terraform {
  backend "s3" {
    bucket         = "mon-bucket-tfstate"
    key            = "exercise-01/terraform.tfstate"
    region         = "eu-west-3"
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }
}
```

Avantages : state centralisé, chiffré, versionné, verrouillé pendant les opérations, et accessible à toute l'équipe et aux pipelines CI/CD.

Documentation :
- Remote state : https://developer.hashicorp.com/terraform/language/state/remote
- Backends : https://developer.hashicorp.com/terraform/language/settings/backends/configuration
- Provider random : https://registry.terraform.io/providers/hashicorp/random/latest/docs

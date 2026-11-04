# Exercice 2 : Premier déploiement sur AWS avec S3

## Objectifs

- Configurer l'authentification AWS pour Terraform
- Déployer une première ressource cloud réelle sur AWS
- Comprendre l'importance des noms de ressources globalement uniques
- Utiliser les tags pour organiser les ressources
- Observer les différences entre le provider random et un provider cloud

---

## Prérequis

Credentials AWS Academy copiés depuis "AWS Details" > "AWS CLI" dans `~/.aws/credentials` :

```ini
[default]
aws_access_key_id = ...
aws_secret_access_key = ...
aws_session_token = ...
```

Ces credentials expirent à la fin de la session du Learner Lab et doivent être recopiés à chaque nouvelle session.

Vérification :

```bash
aws s3 ls
```

---

## Note importante : limitation du Learner Lab

Dans l'environnement AWS Academy Learner Lab, la ressource `aws_s3_bucket` ne fonctionne pas :

```
Error: reading S3 Bucket (...) object lock configuration:
AccessDenied: ... is not authorized to perform: s3:GetBucketObjectLockConfiguration
... with an explicit deny in a service control policy
```

**Explication :** après la création du bucket (et à chaque `plan`), le provider AWS relit toute la configuration du bucket, dont la configuration Object Lock. Cette action est interdite par une Service Control Policy de l'organisation AWS Academy. Une SCP s'applique à tout le compte : aucune permission IAM ni option Terraform ne permet de la contourner. Le bucket est bien créé sur AWS, mais Terraform plante juste après et ne peut plus faire de `plan` tant que le bucket est dans le state.

Le problème est le même avec les versions 5.x et 6.x du provider AWS.

**Contournement retenu :** le bucket est créé par une stack CloudFormation gérée par Terraform (`aws_cloudformation_stack`). Terraform ne lit alors que la stack, pas la configuration S3 du bucket. Le versioning et le chiffrement restent gérés par les ressources Terraform natives demandées dans l'énoncé (`aws_s3_bucket_versioning` et `aws_s3_bucket_server_side_encryption_configuration`), qui ne lisent que leur propre configuration.

Nettoyage effectué après les essais ratés :

```bash
terraform state rm aws_s3_bucket.bucket
aws s3 rb s3://mon-bucket-terraform-<suffixe> --force
```

---

## Partie 1 : Configuration de base

```hcl
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

# Suffixe aléatoire pour rendre le nom du bucket unique
resource "random_id" "suffix" {
  byte_length = 4
}
```

Avec `byte_length = 4`, `random_id.suffix.hex` donne 8 caractères hexadécimaux (ex : `7210a020`).

---

## Partie 2 : Création du bucket S3

### Version attendue par l'énoncé (bloquée dans le Learner Lab)

```hcl
resource "aws_s3_bucket" "bucket" {
  bucket = "mon-bucket-terraform-${random_id.suffix.hex}"

  tags = {
    Name        = "Mon bucket Terraform"
    Environment = "Dev"
    ManagedBy   = "Terraform"
  }
}

output "bucket_name" {
  value = aws_s3_bucket.bucket.bucket
}
```

### Version utilisée (contournement CloudFormation)

```hcl
locals {
  bucket_name = "mon-bucket-terraform-${random_id.suffix.hex}"
}

# aws_s3_bucket est bloqué dans le Learner Lab
# (s3:GetBucketObjectLockConfiguration interdit par une SCP).
# Le bucket est donc créé via une stack CloudFormation gérée par Terraform.
resource "aws_cloudformation_stack" "bucket" {
  name = "bucket-${random_id.suffix.hex}"

  template_body = jsonencode({
    Resources = {
      Bucket = {
        Type = "AWS::S3::Bucket"
        Properties = {
          BucketName = local.bucket_name
          Tags = [
            { Key = "Name", Value = "Mon bucket Terraform" },
            { Key = "Environment", Value = "Dev" },
            { Key = "ManagedBy", Value = "Terraform" }
          ]
        }
      }
    }
    Outputs = {
      BucketName = { Value = { Ref = "Bucket" } }
      BucketArn  = { Value = { "Fn::GetAtt" = ["Bucket", "Arn"] } }
    }
  })
}

output "bucket_name" {
  value = aws_cloudformation_stack.bucket.outputs["BucketName"]
}
```

### Déploiement et vérification

```bash
terraform init
terraform plan
terraform apply
aws s3 ls | grep terraform
```

Le bucket `mon-bucket-terraform-<suffixe>` apparaît dans la liste.

---

## Partie 3 : Configuration avancée du bucket

```hcl
resource "aws_s3_bucket_versioning" "my_bucket_versioning" {
  bucket = aws_cloudformation_stack.bucket.outputs["BucketName"]

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "encryption" {
  bucket = aws_cloudformation_stack.bucket.outputs["BucketName"]

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}
```

Dans la version de l'énoncé, `bucket = aws_s3_bucket.bucket.id`.

### Observation du plan

```
Plan: 2 to add, 0 to change, 0 to destroy.
```

**Le bucket n'est pas recréé.** Il n'apparaît même pas dans le plan : il n'est pas touché. Depuis la version 4 du provider AWS, le versioning et le chiffrement ne sont plus des arguments du bucket mais des **ressources séparées**. Le plan montre donc 2 nouvelles ressources (symbole `+`) rattachées au bucket existant, et non une modification du bucket (`~`). Côté AWS, le résultat est bien une modification de la configuration du bucket, sans destruction ni recréation, et donc sans perte de données.

Le symbole `~` (modification sur place) apparaîtrait par exemple si on changeait un tag du bucket.

---

## Partie 4 : Outputs

```hcl
output "suffix" {
  value = random_id.suffix.hex
}

output "bucket_name" {
  value = aws_cloudformation_stack.bucket.outputs["BucketName"]
}

output "bucket_arn" {
  value = aws_cloudformation_stack.bucket.outputs["BucketArn"]
}

output "bucket_region" {
  value = "us-east-1"
}

output "versioning_status" {
  value = aws_s3_bucket_versioning.my_bucket_versioning.versioning_configuration[0].status
}
```

Dans la version de l'énoncé :

```hcl
output "bucket_name" {
  value = aws_s3_bucket.bucket.bucket
}

output "bucket_arn" {
  value = aws_s3_bucket.bucket.arn
}

output "bucket_region" {
  value = aws_s3_bucket.bucket.bucket_region
}
```

```bash
terraform output
```

```
bucket_arn        = "arn:aws:s3:::mon-bucket-terraform-xxxxxxxx"
bucket_name       = "mon-bucket-terraform-xxxxxxxx"
bucket_region     = "us-east-1"
suffix            = "xxxxxxxx"
versioning_status = "Enabled"
```

Un nouvel output n'apparaît dans `terraform output` qu'après un `terraform apply` : la commande lit le state, elle ne recalcule rien.

---

## Partie 5 : Upload d'un fichier

### `terraform output -help`

Options principales :
- `-raw` : affiche la valeur brute, sans guillemets. Indispensable pour utiliser un output dans une commande shell
- `-json` : affiche les outputs au format JSON (pratique pour les scripts et `jq`)
- `-no-color` : désactive les couleurs
- `-state=chemin` : lit un autre fichier de state

Sans `-raw`, `terraform output bucket_name` renvoie `"mon-bucket-..."` avec les guillemets, et la commande `aws s3 cp` échouerait.

### Tests

```bash
echo "Hello from Terraform!" > test.txt

aws s3 cp test.txt s3://$(terraform output -raw bucket_name)/
aws s3 ls s3://$(terraform output -raw bucket_name)/

aws s3 cp s3://$(terraform output -raw bucket_name)/test.txt downloaded.txt
cat downloaded.txt
```

Résultat : `Hello from Terraform!`. Le fichier a bien été stocké puis récupéré depuis le bucket.

---

## Partie 6 : Le state

### Nombre de ressources trackées

```bash
terraform state list
```

4 ressources :
- `random_id.suffix`
- `aws_cloudformation_stack.bucket` (ou `aws_s3_bucket.bucket` dans la version de l'énoncé)
- `aws_s3_bucket_versioning.my_bucket_versioning`
- `aws_s3_bucket_server_side_encryption_configuration.encryption`

Le fichier `test.txt` n'est pas dans le state : il a été uploadé avec la CLI, Terraform ne le connaît pas.

### Métadonnées AWS

On retrouve dans le state :
- `provider` : `provider["registry.terraform.io/hashicorp/aws"]`
- l'ARN du bucket (`arn:aws:s3:::mon-bucket-terraform-...`)
- la région (`us-east-1`)
- les tags (`tags` et `tags_all`)
- pour la stack : son ID (ARN de la stack CloudFormation), son template, ses outputs
- pour le bucket natif : `bucket_domain_name`, `bucket_regional_domain_name`, `hosted_zone_id`, etc.
- le champ `dependencies` de chaque ressource

### Comparaison avec l'exercice 1

| | Exercice 1 (random) | Exercice 2 (AWS) |
|---|---|---|
| Où vivent les ressources | Uniquement dans le state | Sur AWS, le state n'en garde qu'une copie |
| Attributs | Peu : la valeur générée et les arguments | Beaucoup : ARN, région, domaines, tags, IDs AWS |
| Refresh | Rien à interroger | Terraform appelle les API AWS à chaque `plan` |
| Identifiants | Générés localement | Attribués par AWS |
| Dépendances | Aucune | `dependencies` vers le bucket et le `random_id` |

### `terraform show`

Affiche le contenu du state dans un format lisible (syntaxe proche du HCL) plutôt qu'en JSON brut, avec toutes les ressources et leurs attributs. Les valeurs `sensitive` sont masquées.

---

## Partie 7 : Destruction

### Vider le bucket

Avec le versioning activé, `aws s3 rm` ne supprime que la version courante et ajoute un marqueur de suppression. Les anciennes versions restent et `terraform destroy` échoue avec `BucketNotEmpty`.

Solutions :
- **Console AWS** : S3 > bouton radio à côté du bucket > **Vider** (Empty) > confirmer
- **`force_destroy = true`** sur la ressource `aws_s3_bucket` (version de l'énoncé), suivi d'un `terraform apply` pour l'enregistrer dans le state avant le `destroy`. À réserver aux buckets de test
- **En CLI**, en supprimant toutes les versions et tous les marqueurs :

```bash
BUCKET=$(terraform output -raw bucket_name)

aws s3api delete-objects --bucket $BUCKET --delete \
  "$(aws s3api list-object-versions --bucket $BUCKET \
  --query '{Objects: Versions[].{Key:Key,VersionId:VersionId}}' --output json)"

aws s3api delete-objects --bucket $BUCKET --delete \
  "$(aws s3api list-object-versions --bucket $BUCKET \
  --query '{Objects: DeleteMarkers[].{Key:Key,VersionId:VersionId}}' --output json)"
```

Avec le contournement CloudFormation, `force_destroy` n'existe pas : il faut vider le bucket par la console ou la CLI.

### Destruction

```bash
terraform destroy
aws s3 ls | grep terraform
```

Terraform détruit dans l'ordre inverse des dépendances : d'abord le chiffrement et le versioning, puis le bucket (ou la stack, qui supprime le bucket), et enfin le `random_id`. La dernière commande ne renvoie plus rien : le bucket n'existe plus.

---

## Questions de réflexion

### 1. Unicité globale des noms

**Pourquoi des noms globalement uniques ?** Les noms de buckets S3 partagent un espace de noms unique pour tous les comptes AWS du monde, toutes régions confondues. Le nom sert directement dans l'URL d'accès (`https://<bucket>.s3.amazonaws.com`) et donc dans le DNS. Deux buckets ne peuvent pas avoir la même adresse.

**Réutiliser le même nom :**
- si le bucket appartient à quelqu'un d'autre : erreur `BucketAlreadyExists`
- s'il nous appartient déjà : erreur `BucketAlreadyOwnedByYou`
- après la suppression d'un bucket, le nom peut ne pas être réutilisable tout de suite

Dans une promo où tout le monde suit le même énoncé, un nom fixe comme `mon-bucket-terraform` serait pris par le premier étudiant et ferait échouer tous les autres.

**`random_id` plutôt que `random_pet` :**
- `random_id` produit uniquement des caractères hexadécimaux minuscules (0-9, a-f), toujours conformes aux règles de nommage S3 (minuscules, chiffres, tirets, 3 à 63 caractères)
- la longueur est fixe et courte (8 caractères pour 4 octets), donc on maîtrise la longueur totale du nom
- 4 octets donnent plus de 4 milliards de combinaisons, contre un nombre bien plus limité de combinaisons de mots pour `random_pet`, donc moins de risques de collision
- `random_pet` produit des mots de longueur variable, adaptés pour un nom lisible par un humain (nom de serveur), moins pour un identifiant technique unique

### 2. Dépendances implicites

**Ordre de création :** oui. `random_id.suffix` d'abord, puis le bucket (son nom dépend du suffixe), puis le versioning et le chiffrement, créés en parallèle car ils ne dépendent que du bucket.

**Comment Terraform le sait :** grâce aux **références** dans le code. `bucket = aws_s3_bucket.bucket.id` (ou `aws_cloudformation_stack.bucket.outputs[...]`) indique que la ressource a besoin d'un attribut du bucket. Terraform construit un graphe de dépendances à partir de toutes ces références et l'utilise pour ordonner les créations, et l'inverse pour les destructions. Ces dépendances sont dites implicites, par opposition à `depends_on` qui les déclare explicitement.

Le graphe peut être visualisé avec :

```bash
terraform graph
```

**Dans le state :** oui, chaque instance a un champ `dependencies` :

```json
"dependencies": [
  "aws_cloudformation_stack.bucket",
  "random_id.suffix"
]
```

Terraform s'en sert notamment pour détruire dans le bon ordre, même si les ressources ont été retirées du code.

### 3. State et ressources cloud

**Contenu comparé :** une ressource random ne contient que la valeur générée et ses arguments. Une ressource AWS contient en plus tous les attributs renvoyés par AWS : ARN, région, IDs, noms de domaine, tags effectifs (`tags_all`), configuration complète.

**Pourquoi l'ARN et les métadonnées :**
- l'ARN identifie la ressource de manière unique dans AWS : Terraform s'en sert pour la relire, la modifier et la supprimer
- les attributs servent de référence pour d'autres ressources (une policy IAM qui cible l'ARN du bucket, par exemple)
- ils permettent de comparer l'état réel avec le code pour détecter les écarts (drift)
- ils évitent de refaire des appels API pour connaître des valeurs déjà connues

**Suppression manuelle dans la console puis `terraform plan` :** au refresh, Terraform interroge AWS et constate que le bucket n'existe plus. Il le retire du state et le plan propose de le **recréer** (`+`), ainsi que le versioning et le chiffrement. Le contenu du bucket, lui, est perdu définitivement : Terraform recrée un bucket vide.

### 4. Ressources AWS vs ressources random

**Différence fondamentale :** une ressource `random_*` est **purement logique**. Elle n'existe que dans le state, n'appelle aucune API externe, ne coûte rien et peut être recréée sans conséquence en dehors de Terraform. Une ressource `aws_*` crée une **vraie infrastructure** via les API AWS : elle existe indépendamment de Terraform, peut être modifiée par d'autres personnes, contient des données et génère des coûts.

**La plus risquée :** les ressources AWS.
- une destruction ou un remplacement efface de vraies données (souvent sans retour possible)
- elles coûtent de l'argent tant qu'elles existent, y compris si on oublie de les détruire
- une mauvaise configuration peut exposer des données (bucket public, par exemple)
- elles dépendent de permissions, de quotas et de restrictions (comme la SCP du Learner Lab)
- elles peuvent être modifiées hors Terraform, ce qui crée des écarts avec le state

Et indirectement, une ressource random peut devenir risquée : si on remplace `random_id.suffix`, le nom du bucket change et Terraform remplace aussi le bucket.

### 5. Tags et organisation

**À quoi servent les tags :**
- identifier et organiser les ressources (projet, environnement, propriétaire)
- suivre et répartir les coûts (cost allocation tags dans la facturation)
- automatiser (scripts de nettoyage, sauvegardes ciblées, arrêt des environnements de dev la nuit)
- contrôler les accès avec des policies IAM basées sur les tags (ABAC)
- savoir qui gère quoi : `ManagedBy = "Terraform"` indique qu'il ne faut pas modifier la ressource à la main

**Organiser plusieurs projets Terraform :** définir des tags communs à chaque projet (`Project`, `Environment`, `Owner`, `ManagedBy`, éventuellement `Repository`) et les appliquer automatiquement à toutes les ressources du provider avec `default_tags` :

```hcl
provider "aws" {
  region = "us-east-1"

  default_tags {
    tags = {
      Project     = "ig2i-terraform"
      Environment = "Dev"
      ManagedBy   = "Terraform"
      Owner       = "achrafe.nassiri"
    }
  }
}
```

Chaque ressource peut ensuite ajouter ses propres tags (comme `Name`). C'est ce qui donne l'attribut `tags_all` dans le state : la fusion des `default_tags` et des tags de la ressource.

**Retrouver les ressources `ManagedBy = "Terraform"` :**
- **Console** : Resource Groups & Tag Editor > Tag Editor, recherche par tag dans toutes les régions et tous les types de ressources
- **CLI** :

```bash
aws resourcegroupstaggingapi get-resources \
  --tag-filters Key=ManagedBy,Values=Terraform \
  --query "ResourceTagMappingList[].ResourceARN"
```

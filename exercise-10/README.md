# Exercice 10 : Remote state avec un backend S3

## Objectifs pédagogiques

- Créer le bucket de state (versioning, chiffrement, verrouillage)
- Migrer un state local vers S3

## Contexte

Le state local suffit pour les exercices précédents. Dès qu'on travaille à plusieurs, ou dès qu'on veut protéger le state, il vit dans un backend distant : chiffrement, verrouillage contre deux `apply` simultanés, copie du state hors de la machine.

Le bucket doit exister **avant** la configuration du backend. On le crée dans une configuration séparée, exécutée une seule fois, qui garde son propre state en local : le bucket ne peut pas stocker ce state avant d'exister. Le verrouillage s'active avec `use_lockfile = true` : Terraform pose un fichier de verrou à côté du state.

La configuration partielle par environnement et la lecture d'un autre state avec `terraform_remote_state` sont dans l'exercice 99, section 2.

## Prérequis

- Avoir complété l'exercice 09
- Avoir configuré les identifiants AWS
- Terraform 1.11 ou plus récent (`use_lockfile` dans le backend S3)

---

## Partie 1 : Créer le bucket de state

### Objectif

Créer l'infrastructure du backend dans `exercise-10/bootstrap/`.

### Instructions

1. Copiez le contenu de `exercise-10/starter/` dans `exercise-10/`. Vous obtenez `bootstrap/` et `project/`, en squelette avec des `# TODO`.

2. Dans `bootstrap/variables.tf`, ajoutez `bucket_prefix` : type `string`, valeur par défaut `ig2i-tfstate`, validation entre 3 et 20 caractères.

3. Dans `bootstrap/main.tf`, déclarez :
   - un `random_id` pour rendre le nom unique sur AWS ;
   - un `aws_s3_bucket` nommé `terraform_state`, de nom `<prefix>-<suffixe>`, protégé contre la suppression par un bloc `lifecycle` avec `prevent_destroy = true` ;
   - un `aws_s3_bucket_versioning` qui active le versioning de ce bucket : chaque écriture du state garde la version précédente ;
   - un `aws_s3_bucket_server_side_encryption_configuration` qui chiffre le bucket en `AES256`.

   `prevent_destroy` fait échouer tout plan qui supprimerait le bucket. Le retrait de ce bloc fait partie du nettoyage.

4. Dans `bootstrap/outputs.tf`, exposez `state_bucket` (nom du bucket) et `aws_region` (région du bucket).

5. Appliquez, puis notez les deux outputs.

```bash
cd exercise-10/bootstrap
terraform init
terraform apply
terraform output
```

---

## Partie 2 : Migrer un state vers S3

### Objectif

Créer un bucket applicatif avec un state local, puis envoyer ce state dans le bucket de la partie 1.

### Instructions

1. Dans `project/variables.tf`, ajoutez `bucket_prefix` : type `string`, valeur par défaut `ig2i-ex10`, validation entre 3 et 20 caractères.

2. Dans `project/main.tf`, déclarez un `random_id` et un `aws_s3_bucket` nommé `app`, de nom `<prefix>-<suffixe>`, avec les tags `Purpose = "Application"` et `ManagedBy = "Terraform"`.

3. Dans `project/outputs.tf`, exposez `bucket_id` et `bucket_arn`.

4. Appliquez **sans** bloc `backend`. Le state est encore le fichier local. Ne le commitez pas.

```bash
cd exercise-10/project
terraform init
terraform apply
```

5. Créez `project/backend.tf` avec un bloc `terraform { backend "s3" { ... } }`. Les arguments à renseigner :

| Argument | Valeur |
| --- | --- |
| `bucket` | output `state_bucket` de la partie 1 |
| `key` | `project/terraform.tfstate` |
| `region` | output `aws_region` de la partie 1 |
| `encrypt` | `true` |
| `use_lockfile` | `true` |

   Un bloc `backend` n'accepte ni variable ni interpolation : le nom du bucket et la région y sont des littéraux, recopiés depuis `terraform output`. Si vous avez changé `aws_region` dans `bootstrap/`, reportez la même région ici.

6. Migrez. Terraform demande confirmation avant de copier le state.

```bash
terraform init -migrate-state
terraform plan
```

`terraform plan` ne doit proposer aucun changement : la ressource existe déjà, seul l'endroit où le state est stocké a changé.

---

## Points d'attention

- Le bucket de state est créé avant le backend
- Une fois le backend configuré, `terraform.tfstate` ne se commite pas
- `use_lockfile` empêche deux modifications simultanées
- Un verrou resté bloqué se retire avec `terraform force-unlock <LOCK_ID>`
- `prevent_destroy` sur le bucket de state empêche sa suppression tant que le bloc est présent

---

## Validation

La configuration doit :

- Créer, depuis `bootstrap/`, un bucket versionné et chiffré
- Activer le verrouillage avec `use_lockfile = true`
- Après `terraform init -migrate-state`, afficher un `terraform plan` sans changement dans `project/`
- Ranger le state sous la clé `project/terraform.tfstate`

---

## Nettoyage

Détruisez d'abord le projet, pendant que le backend fonctionne encore. Détruire `bootstrap/` avant `project/` rend le state distant illisible.

```bash
cd exercise-10/project
terraform destroy
```

Le bucket de state refuse le `destroy` à cause de `prevent_destroy`. Il contient aussi les anciennes versions du state, conservées par le versioning, et AWS ne supprime pas un bucket qui n'est pas vide.

1. Dans `bootstrap/main.tf`, retirez le bloc `lifecycle` du bucket et ajoutez à sa place `force_destroy = true`. Cet argument autorise Terraform à supprimer tous les objets du bucket, anciennes versions comprises, avant le bucket lui-même.

2. Appliquez pour enregistrer `force_destroy` dans le state, puis détruisez.

```bash
cd exercise-10/bootstrap
terraform apply
terraform destroy
```

`force_destroy` n'est pris en compte qu'après l'`apply` : un `destroy` lancé directement échoue sur le bucket non vide.

---

## Ressources

- [Backend S3](https://developer.hashicorp.com/terraform/language/settings/backends/s3)
- [lifecycle et prevent_destroy](https://developer.hashicorp.com/terraform/language/meta-arguments/lifecycle)
- [aws_s3_bucket, argument force_destroy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket)
- [Remote State Data Source](https://developer.hashicorp.com/terraform/language/state/remote-state-data)

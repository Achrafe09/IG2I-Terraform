# Exercice 9 : Workspaces pour gérer plusieurs environnements

## Objectifs pédagogiques

- Créer, lister et sélectionner des workspaces
- Faire dépendre le nom d'une ressource et ses paramètres de `terraform.workspace`
- Constater que chaque workspace a son propre state

## Contexte

Les workspaces permettent de gérer plusieurs environnements (dev, staging, prod) avec le même code, quand ces environnements sont très similaires : même structure, paramètres différents. C'est une alternative aux répertoires séparés pour les petits projets.

Dans le code, le nom du workspace actif se lit avec `terraform.workspace`.

## Prérequis

- Avoir complété l'exercice 08
- Avoir configuré les identifiants AWS

---

## Partie 1 : Nommer le bucket selon l'environnement

### Objectif

Créer un bucket dont le nom et le tag `Environment` contiennent le workspace actif.

### Instructions

1. Copiez le contenu de `exercise-09/starter/` dans `exercise-09/`. Les fichiers y sont en squelette, avec des `# TODO`.

2. Dans `variables.tf`, ajoutez `bucket_prefix` : type `string`, valeur par défaut `ig2i-ex09`, validation entre 3 et 20 caractères.

3. Dans `main.tf`, créez un `random_id` et un `aws_s3_bucket` nommé `data` :
   - nom du bucket : `<prefix>-<workspace>-<suffixe>` ;
   - tag `Environment` : le nom du workspace.

   Le préfixe et le suffixe aléatoire rendent le nom unique sur AWS. Le nom du workspace permet de reconnaître l'environnement dans la console.

---

## Partie 2 : Des paramètres différents par environnement

### Objectif

Sélectionner un type et un nombre d'instances selon le workspace. Aucune instance EC2 n'est créée : les valeurs sont seulement exposées par des outputs.

### Instructions

1. Les valeurs attendues :

| Workspace | Type d'instance | Nombre d'instances |
| --- | --- | --- |
| `default` | `t2.micro` | 1 |
| `dev` | `t2.micro` | 1 |
| `staging` | `t3.small` | 2 |
| `prod` | `t3.large` | 5 |

   Le workspace `default` existe toujours et ne peut pas être supprimé. Il reçoit les mêmes valeurs que `dev` : sans cette entrée, un `plan` lancé avant le premier changement de workspace échoue sur une clé absente de la map.

2. Le type d'instance est une valeur calculée : dans `locals.tf`, déclarez une map `instance_types` (une entrée par workspace) et un local `instance_type` qui y lit l'entrée du workspace actif.

3. Le nombre d'instances est un paramètre que l'utilisateur peut changer : dans `variables.tf`, déclarez `instance_counts`, de type `map(number)`, avec les valeurs du tableau comme défaut.

4. Dans `outputs.tf`, exposez :

| Output | Valeur |
| --- | --- |
| `bucket_name` | Nom du bucket du workspace actif |
| `workspace` | Workspace actif |
| `instance_type` | Type d'instance retenu pour le workspace actif |
| `instance_count` | Nombre d'instances retenu pour le workspace actif |

   Une ressource EC2 utiliserait ces mêmes expressions dans `instance_type` et `count`.

---

## Partie 3 : Les workspaces

### Objectif

Appliquer dans `dev`, puis observer que `staging` a un state vide.

### Commandes

```bash
terraform workspace list            # lister les workspaces
terraform workspace new <nom>       # créer un workspace et le sélectionner
terraform workspace select <nom>    # changer de workspace
terraform workspace show            # afficher le workspace actif
```

### Instructions

1. Initialisez dans `exercise-09/`, puis créez les workspaces `dev`, `staging` et `prod`.

2. Sélectionnez `dev`, faites un `terraform apply`, puis `terraform output`.

3. Sélectionnez `staging` et lancez `terraform plan`.

Le `plan` dans `staging` propose de créer un bucket. Il ne propose pas de modifier celui de `dev` : ce n'est pas le même state. Le suffixe aléatoire est lui aussi propre à chaque workspace.

4. Sélectionnez `prod` et lancez `terraform plan` : les outputs prévus montrent les valeurs de `prod`.

Sans backend distant, Terraform range chaque workspace dans `terraform.tfstate.d/<workspace>/terraform.tfstate`. Le workspace `default` reste dans `terraform.tfstate`.

Vérifiez le workspace actif avec `terraform workspace show` avant un `apply`. La comparaison avec des répertoires séparés, et le rangement des workspaces dans un backend S3, sont dans l'exercice 99, section 3.

---

## Validation

La configuration doit :

- Avoir les workspaces `dev`, `staging` et `prod`
- Créer dans `dev` un bucket dont le nom contient `dev` et dont le tag `Environment` vaut `dev`
- Proposer, dans `staging`, la création d'un autre bucket, sans toucher à celui de `dev`
- Afficher `t2.micro` / `1` dans `dev` et `t3.large` / `5` dans `prod`

---

## Nettoyage

`terraform destroy` ne concerne que le workspace actif. Répétez-le dans chaque workspace où un `apply` a été fait (ici, `dev`), puis supprimez les workspaces. Un workspace ne peut pas être supprimé tant qu'il est sélectionné ou que son state contient des ressources.

```bash
terraform workspace select dev
terraform destroy

terraform workspace select default
terraform workspace delete dev
terraform workspace delete staging
terraform workspace delete prod
```

---

## Ressources

- [Documentation Workspaces](https://developer.hashicorp.com/terraform/language/state/workspaces)
- [Commande terraform workspace](https://developer.hashicorp.com/terraform/cli/commands/workspace)
- [Managing Environments](https://developer.hashicorp.com/terraform/tutorials/modules/organize-configuration)

# Exercice 8 : Modules pour l'infrastructure réutilisable

## Objectifs pédagogiques

- Découper une configuration réutilisable en module (`main.tf`, `variables.tf`, `outputs.tf`)
- Appeler deux fois un module local avec des paramètres différents
- N'exposer que les outputs nécessaires

## Contexte

Un module regroupe plusieurs ressources derrière une interface : des variables en entrée, des outputs en sortie. On s'en sert pour :

- Créer des composants d'infrastructure réutilisables (ici, un bucket S3 standard)
- Standardiser les configurations dans une équipe
- Partager des patterns entre projets
- Encapsuler la complexité

Le module de cet exercice reprend le bucket, le versioning conditionnel et le blocage de l'accès public déjà vus dans les exercices précédents.

## Prérequis

- Avoir complété l'exercice 07
- Savoir déclarer des variables, des outputs et un `count` conditionnel

---

## Partie 1 : Écrire le module `s3-bucket`

### Objectif

Isoler la définition du bucket dans `exercise-08/modules/s3-bucket/`.

### Structure attendue

```
exercise-08/
├── main.tf
├── variables.tf
├── outputs.tf
└── modules/
    └── s3-bucket/
        ├── versions.tf
        ├── main.tf
        ├── variables.tf
        ├── outputs.tf
        └── README.md
```

### Instructions

1. Copiez le contenu de `exercise-08/starter/` dans `exercise-08/`. Les fichiers de la configuration appelante y sont en squelette, avec des `# TODO`.

2. Créez le répertoire `exercise-08/modules/s3-bucket/`.

3. Dans `variables.tf` du module, déclarez les inputs suivants, chacun avec une `description` :

| Nom | Type | Défaut | Rôle |
| --- | --- | --- | --- |
| `bucket_name` | `string` | aucun (obligatoire) | Nom du bucket |
| `versioning_enabled` | `bool` | `false` | Activer le versioning |
| `tags` | `map(string)` | `{}` | Tags à appliquer au bucket |

4. Dans `main.tf` du module, déclarez :
   - un `aws_s3_bucket` nommé `this`, qui prend son nom et ses tags dans les variables du module ;
   - un `aws_s3_bucket_versioning`, créé seulement si `versioning_enabled` vaut `true` (le `count` conditionnel de l'exercice 07) ;
   - un `aws_s3_bucket_public_access_block` qui bloque les quatre formes d'accès public.

   Le nom `this` est la convention pour la ressource principale d'un module qui n'en contient qu'une de ce type.

5. Dans `outputs.tf` du module, exposez `bucket_id` et `bucket_arn`, avec une `description`.

6. Dans `versions.tf` du module, déclarez le provider dont le module a besoin, dans un bloc `terraform { required_providers { ... } }`. Indiquez une version minimale (`>=`), pas une contrainte `~>` : c'est la configuration appelante qui fixe la version exacte. Le module ne contient pas de bloc `provider` : la région et les identifiants viennent de la configuration appelante.

7. Documentez le module dans son `README.md` : une phrase sur ce qu'il crée, un tableau des inputs (nom, type, défaut, description), un tableau des outputs.

---

## Partie 2 : Utiliser le module deux fois

### Objectif

Créer un bucket de logs sans versioning et un bucket de sauvegardes avec versioning, à partir du même module.

Le nom du bucket est un input du module. Il doit être unique sur l'ensemble d'AWS : le suffixe aléatoire, déjà utilisé depuis l'exercice 02, est calculé dans la configuration appelante, pas dans le module.

### Instructions

1. Dans `exercise-08/variables.tf`, ajoutez `bucket_prefix` : type `string`, valeur par défaut `ig2i-ex08`, validation entre 3 et 20 caractères.

2. Dans `exercise-08/main.tf` :
   - créez un `random_id` qui servira de suffixe aux deux noms ;
   - appelez le module deux fois avec un bloc `module`, en indiquant `source = "./modules/s3-bucket"` :

| Bloc `module` | Nom du bucket | `versioning_enabled` | Tags |
| --- | --- | --- | --- |
| `logs_bucket` | `<prefix>-logs-<suffixe>` | `false` | `Purpose = "Logs"`, `Environment = "production"` |
| `backups_bucket` | `<prefix>-backups-<suffixe>` | `true` | `Purpose = "Backups"`, `Environment = "production"` |

   La syntaxe d'un appel de module est décrite dans [Module Blocks](https://developer.hashicorp.com/terraform/language/modules/syntax).

3. Dans `exercise-08/outputs.tf`, exposez `logs_bucket_arn` et `backups_bucket_arn`. Un output de module se lit avec `module.<nom>.<output>`.

4. Initialisez, puis appliquez. `terraform init` charge le module local : relancez-le après avoir ajouté ou déplacé un module.

```bash
cd exercise-08
terraform init
terraform plan
terraform apply
terraform output
terraform state list
```

`terraform state list` montre les adresses préfixées par le module, par exemple `module.logs_bucket.aws_s3_bucket.this`. Le bucket de logs n'a pas de ressource `aws_s3_bucket_versioning` : `versioning_enabled` vaut `false`. Le bucket de sauvegardes en a une.

Les modules distants (registry, Git) sont décrits dans l'exercice 99, section 1.

---

## Bonnes pratiques

1. **Un module = un objectif** : ne créez pas de module fourre-tout
2. **Documentation** : documentez les inputs, les outputs et un exemple
3. **Versioning** : utilisez une version précise pour un module distant
4. **Tests** : essayez le module avec des configurations différentes (ici, versioning activé et désactivé)
5. **Outputs explicites** : n'exposez que les outputs nécessaires

---

## Validation

La configuration doit :

- Vivre dans `modules/s3-bucket/` avec `versions.tf`, `main.tf`, `variables.tf`, `outputs.tf` et `README.md`
- Appeler ce module deux fois, avec `versioning_enabled` à `false` puis à `true`
- Afficher `logs_bucket_arn` et `backups_bucket_arn`
- Montrer dans `terraform state list` des adresses qui commencent par `module.logs_bucket` et `module.backups_bucket`

---

## Nettoyage

```bash
terraform destroy
```

Le `destroy` lancé dans `exercise-08/` supprime les deux buckets, parce que les ressources du module font partie du même state.

---

## Ressources

- [Documentation Modules](https://developer.hashicorp.com/terraform/language/modules)
- [Module Blocks](https://developer.hashicorp.com/terraform/language/modules/syntax)
- [Provider Requirements in Modules](https://developer.hashicorp.com/terraform/language/modules/develop/providers)
- [Terraform Registry](https://registry.terraform.io/browse/modules)
- [Module Best Practices](https://developer.hashicorp.com/terraform/language/modules/develop)

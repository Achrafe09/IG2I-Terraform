# Exercice 11 : Importer une ressource créée manuellement

## Objectifs pédagogiques

- Créer un bucket S3 en dehors de Terraform
- L'adopter avec `terraform import`
- Ajuster la configuration jusqu'à ce que `terraform plan` ne propose plus de changement

## Contexte

`terraform import` sert à reprendre le contrôle d'une ressource qui existe déjà :

- Ressource créée à la main dans la console AWS
- Infrastructure à migrer vers Terraform
- State perdu, ressource toujours présente
- Ressource créée par un autre outil

L'import modifie le state. Il ne crée pas la ressource, il n'écrit pas le fichier `.tf`, et il ne revient pas en arrière. Les blocs `import` déclaratifs, les identifiants des autres types de ressources et Terraformer sont dans l'exercice 99, section 5.

## Prérequis

- Avoir complété l'exercice 10
- Avoir configuré les identifiants AWS

---

## Partie 1 : Créer le bucket hors de Terraform

### Objectif

Avoir un bucket qui existe dans AWS, porte des tags, et n'est dans aucun state Terraform.

Choisissez un nom unique, par exemple `ig2i-ex11-votre-nom`. En `us-east-1`, la création par la CLI n'a pas de `LocationConstraint`.

```bash
aws s3api create-bucket \
  --bucket ig2i-ex11-votre-nom \
  --region us-east-1

aws s3api put-bucket-tagging \
  --bucket ig2i-ex11-votre-nom \
  --tagging 'TagSet=[{Key=Purpose,Value=ig2i-ex11},{Key=CreatedBy,Value=aws-cli}]'
```

La même création peut se faire dans la console AWS. Notez le nom exact : c'est l'identifiant d'import d'un bucket S3.

---

## Partie 2 : Écrire la configuration

### Objectif

Déclarer le bucket avant de l'importer : `terraform import` rattache une ressource existante à une adresse qui doit déjà figurer dans la configuration.

### Instructions

1. Copiez le contenu de `exercise-11/starter/` dans `exercise-11/`. Les fichiers y sont en squelette, avec des `# TODO`.

2. Dans `variables.tf`, déclarez `bucket_name` : type `string`, avec une `description`, sans valeur par défaut. Chaque étudiant a son propre nom de bucket.

3. Créez `terraform.tfvars` et donnez-y à `bucket_name` le nom choisi à la partie 1. Ce fichier est lu automatiquement par `plan`, `apply`, `import` et `destroy`.

4. Dans `main.tf`, déclarez une ressource `aws_s3_bucket` nommée `imported`, dont le nom vient de `var.bucket_name`. N'y mettez rien d'autre pour l'instant : la partie 3 montre ce qui manque.

5. Dans `outputs.tf`, exposez `bucket_id`.

6. Initialisez. Ne lancez pas `terraform apply` : le bucket existe déjà, et un apply tenterait de le créer une seconde fois.

```bash
cd exercise-11
terraform init
```

---

## Partie 3 : Importer, puis faire coller la configuration

### Objectif

Enregistrer le bucket dans le state, puis supprimer l'écart entre le fichier `.tf` et la ressource réelle.

### Instructions

1. Avant un import dans un state qui existe déjà, copiez ce state sous un nom que Terraform n'utilise pas, par exemple `cp terraform.tfstate terraform.tfstate.pre-import`. Le nom `terraform.tfstate.backup` est à éviter : Terraform l'écrase à chaque écriture du state. Ici, juste après `terraform init`, le state n'existe pas encore : il n'y a rien à copier.

2. Importez le bucket. La syntaxe est `terraform import <type>.<nom> <id>`. Pour un bucket S3, l'id est le nom du bucket. Vérifiez ensuite avec `terraform state list` que `aws_s3_bucket.imported` est dans le state.

3. Comparez la configuration et la ressource.

```bash
terraform plan
terraform show
```

`terraform plan` montre ce que Terraform changerait pour que le bucket corresponde au fichier `.tf`. Ici, il propose de retirer les deux tags posés à la partie 1 : la configuration n'en déclare aucun. Appliquer ce plan modifierait un bucket qu'on voulait seulement reprendre.

4. Complétez la ressource dans `main.tf` à partir de ce que montre `terraform show`, sans lancer d'`apply`, jusqu'à ce que `terraform plan` affiche `No changes`.

Le versioning et le chiffrement d'un bucket sont des ressources Terraform séparées (`aws_s3_bucket_versioning`, `aws_s3_bucket_server_side_encryption_configuration`). Les reprendre demande un import de plus, avec leur propre identifiant. Ce n'est pas demandé ici.

---

## Validation

La configuration doit :

- Déclarer `aws_s3_bucket.imported` avec le nom du bucket créé hors de Terraform
- Contenir cette ressource dans le state après `terraform import`
- Déclarer les tags posés hors de Terraform
- Produire un `terraform plan` sans changement

---

## Nettoyage

`terraform destroy` supprime le bucket, puisqu'il est maintenant dans le state. Le bucket doit être vide.

```bash
terraform destroy
```

---

## Ressources

- [Import Command](https://developer.hashicorp.com/terraform/cli/commands/import)
- [Import blocks](https://developer.hashicorp.com/terraform/language/import)
- [aws_s3_bucket import](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket#import)
- [aws s3api put-bucket-tagging](https://docs.aws.amazon.com/cli/latest/reference/s3api/put-bucket-tagging.html)

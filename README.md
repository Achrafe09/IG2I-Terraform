# Formation Terraform - IG2I

Ce dépôt contient des exercices progressifs enseignant les concepts d'Infrastructure as Code avec Terraform, conçus pour les étudiants de l'IG2I.

## Support de cours

Consultez les slides du cours en ligne : [Cours d'introduction à Terraform](https://frederictriquet.github.io/IG2I-Terraform/)

Version PDF : [cours-slides.pdf](https://frederictriquet.github.io/IG2I-Terraform/cours-slides.pdf)

## Exercices

Les exercices se construisent progressivement les uns sur les autres. Complétez-les dans l'ordre :

* Exercice 00 : Configuration de l'environnement sur Red Hat avec Terraform, VSCode et les identifiants AWS
* Exercice 01 : Fondamentaux de la gestion d'état avec le provider random (pas besoin de cloud)
* Exercice 02 : Premier déploiement AWS réel avec buckets S3, authentification et tagging
* Exercice 03 : Variables, types, validation et organisation des fichiers
* Exercice 04 : Locals pour les valeurs calculées, principe DRY et fonction merge
* Exercice 05 : Outputs et Data Sources pour interroger l'infrastructure existante
* Exercice 06 : Count et For-Each pour créer plusieurs ressources similaires
* Exercice 07 : Ressources conditionnelles et blocs dynamic pour une infrastructure flexible
* Exercice 08 : Modules pour réutiliser un bucket S3
* Exercice 09 : Workspaces pour gérer plusieurs environnements avec le même code
* Exercice 10 : Remote state avec un backend S3
* Exercice 11 : `terraform import` pour reprendre un bucket S3 créé manuellement
* Exercice 99 : Guide de référence sur des concepts avancés de Terraform : modules distants, backend partiel, structures de données et fonctions, provisioners, intégration avec Ansible, tests et outils de validation


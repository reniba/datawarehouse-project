# Projeto de Data Warehouse e Analytics

Bem-vindo ao repositório do **Projeto de Data Warehouse e Analytics**! 🚀
Este projeto constrói um data warehouse completo em SQL, desde a ingestão dos dados brutos até um modelo pronto para análise. Foi desenvolvido durante a **Capacitação 03 – SQL para Data Warehouse** do Trainee do Núcleo de Dados (NDados) da EESC jr., seguindo o tutorial [SQL Data Warehouse from Scratch | Full Hands-On Data Engineering Project](https://www.youtube.com/watch?v=9GVqKuTVANE).

---

## 🏗️ Arquitetura de Dados

O projeto segue a **Arquitetura Medalhão**, com as camadas **Bronze**, **Prata (Silver)** e **Ouro (Gold)**:

![Arquitetura de Dados](docs/data_architecture.png)

1. **Camada Bronze**: armazena os dados brutos exatamente como vieram dos sistemas de origem. Os dados são carregados dos arquivos CSV para o banco SQL Server com `BULK INSERT`.
2. **Camada Prata**: faz a limpeza, padronização e normalização dos dados (remoção de duplicados, tratamento de nulos e datas inválidas, padronização de valores) para prepará-los para análise.
3. **Camada Ouro**: contém os dados prontos para o negócio, modelados em **esquema estrela** (star schema) por meio de views, voltados para relatórios e análises.

---

## 📖 Visão Geral do Projeto

O projeto envolve:

1. **Arquitetura de Dados**: desenho de um data warehouse moderno usando a Arquitetura Medalhão.
2. **Pipelines de ETL**: extração, transformação e carga dos dados dos sistemas de origem para o warehouse.
3. **Modelagem de Dados**: criação de tabelas de fatos e dimensões otimizadas para consultas analíticas.
4. **Analytics e Relatórios**: consultas SQL que geram insights para o negócio.

---

## 📥 Fontes de Dados

Os dados vêm de **dois sistemas de origem**, fornecidos como arquivos CSV:

- **CRM**: informações de clientes, produtos e detalhes das vendas.
- **ERP**: informações complementares de clientes (data de nascimento, gênero, país) e categorias de produtos.

---

## ⭐ Tabelas da Camada Ouro

| Objeto | Tipo | Descrição |
|---|---|---|
| `gold.dim_customers` | Dimensão | Clientes com dados integrados do CRM e do ERP |
| `gold.dim_products` | Dimensão | Produtos ativos com suas categorias e subcategorias |
| `gold.fact_sales` | Fato | Vendas, ligadas às dimensões por chaves substitutas (surrogate keys) |

---

## 🛠️ Ferramentas Utilizadas

- **[SQL Server Express](https://www.microsoft.com/pt-br/sql-server/sql-server-downloads):** servidor leve para hospedar o banco de dados.
- **[SQL Server Management Studio (SSMS)](https://learn.microsoft.com/pt-br/sql/ssms/download-sql-server-management-studio-ssms):** interface para gerenciar e consultar o banco.
- **[GitHub](https://github.com/):** versionamento do código.
- **[Draw.io](https://www.drawio.com/):** diagramas de arquitetura, fluxo e modelo de dados.

---

## 🚀 Requisitos do Projeto

### Construção do Data Warehouse (Engenharia de Dados)

#### Objetivo
Desenvolver um data warehouse moderno em SQL Server para consolidar dados de vendas, permitindo relatórios analíticos e tomada de decisão embasada.

#### Especificações
- **Fontes de Dados**: importar dados de dois sistemas (ERP e CRM) fornecidos como CSV.
- **Qualidade dos Dados**: limpar e resolver problemas de qualidade antes da análise.
- **Integração**: combinar as duas fontes em um único modelo de dados, fácil de usar e voltado a consultas analíticas.
- **Escopo**: considerar apenas o conjunto de dados mais recente; não é necessário manter histórico.
- **Documentação**: documentar o modelo de dados de forma clara para as áreas de negócio e de análise.

### BI: Analytics e Relatórios (Análise de Dados)

#### Objetivo
Desenvolver análises em SQL que tragam insights sobre:
- **Comportamento dos clientes**
- **Desempenho dos produtos**
- **Tendências de vendas**

---

## 📂 Estrutura do Repositório

```
sql-data-warehouse-project/
│
├── datasets/                           # Dados brutos usados no projeto (CRM e ERP)
│
├── docs/                               # Documentação e diagramas do projeto
│   ├── data_architecture.drawio        # Arquitetura do projeto
│   ├── data_catalog.md                 # Catálogo dos dados, com descrição dos campos
│   ├── data_flow.drawio                # Diagrama do fluxo de dados
│   ├── data_models.drawio              # Modelo de dados (esquema estrela)
│   ├── naming-conventions.md           # Convenções de nomenclatura de tabelas, colunas e arquivos
│
├── scripts/                            # Scripts SQL de ETL e transformação
│   ├── init_database.sql               # Criação do banco e dos schemas
│   ├── bronze/                         # Criação e carga da camada Bronze
│   ├── silver/                         # Limpeza e transformação (camada Prata)
│   ├── gold/                           # Views do modelo analítico (camada Ouro)
│
├── tests/                              # Scripts de verificação de qualidade dos dados
│
├── README.md                           # Visão geral do projeto
└── .gitignore                          # Arquivos ignorados pelo Git
```

---

## ▶️ Como Executar

1. Rode `scripts/init_database.sql` para criar o banco `DataWarehouse` e os schemas `bronze`, `silver` e `gold`.
2. Crie as tabelas da Bronze e carregue os dados com `EXEC bronze.load_bronze;`
3. Crie as tabelas da Prata e carregue os dados com `EXEC silver.load_silver;`
4. Rode os scripts de `scripts/gold/` para criar as views da camada Ouro.
5. (Opcional) Rode os scripts de `tests/` para validar a qualidade dos dados.

> ⚠️ Ajuste os caminhos dos arquivos CSV no `BULK INSERT` para a pasta onde os datasets estão no seu computador.

---

## 🙏 Créditos

Projeto baseado no tutorial gratuito de **Baraa Khatib Salkini ([Data With Baraa](https://www.youtube.com/@datawithbaraa))**. Repositório original: [DataWithBaraa/sql-data-warehouse-project](https://github.com/DataWithBaraa/sql-data-warehouse-project).

## 👤 Autor

**[Seu Nome]** – Trainee 2026.2 do Núcleo de Dados da EESC jr.
[LinkedIn](https://linkedin.com/in/seu-perfil) · [GitHub](https://github.com/seu-usuario)
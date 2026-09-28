# **Convenções de Nomenclatura**

Este documento descreve as convenções de nomenclatura usadas para schemas, tabelas, views, colunas e demais objetos do data warehouse.

## **Sumário**

- [**Convenções de Nomenclatura**](#convenções-de-nomenclatura)
  - [**Sumário**](#sumário)
  - [**Princípios Gerais**](#princípios-gerais)
  - [**Nomenclatura de Tabelas**](#nomenclatura-de-tabelas)
    - [**Regras da Bronze**](#regras-da-bronze)
    - [**Regras da Prata**](#regras-da-prata)
    - [**Regras da Ouro**](#regras-da-ouro)
      - [**Glossário de Prefixos**](#glossário-de-prefixos)
  - [**Nomenclatura de Colunas**](#nomenclatura-de-colunas)
    - [**Chaves Substitutas**](#chaves-substitutas)
    - [**Colunas Técnicas**](#colunas-técnicas)
  - [**Stored Procedures**](#stored-procedures)

---

## **Princípios Gerais**

- **Padrão de escrita**: usar *snake_case*, com letras minúsculas e underscore (`_`) separando as palavras.
- **Idioma**: os nomes dos objetos (schemas, tabelas, colunas, procedures) ficam em **inglês**, mantendo o padrão dos sistemas de origem. A documentação é escrita em português.
- **Palavras reservadas**: não usar palavras reservadas do SQL como nome de objetos.
- **Schemas**: cada camada tem seu próprio schema: `bronze`, `silver` e `gold`.

## **Nomenclatura de Tabelas**

### **Regras da Bronze**
- Todo nome começa com o nome do sistema de origem, seguido do nome original da tabela, **sem renomear**.
- **`<sistema_origem>_<entidade>`**
  - `<sistema_origem>`: nome do sistema de origem (`crm` ou `erp`).
  - `<entidade>`: nome exato da tabela (arquivo CSV) no sistema de origem.
  - Exemplo: `bronze.crm_cust_info` → informações de clientes vindas do CRM.

Tabelas da Bronze no projeto:

| Tabela | Origem | Conteúdo |
|---|---|---|
| `bronze.crm_cust_info` | CRM | Cadastro de clientes |
| `bronze.crm_prd_info` | CRM | Cadastro de produtos |
| `bronze.crm_sales_details` | CRM | Detalhes das vendas |
| `bronze.erp_cust_az12` | ERP | Data de nascimento e gênero dos clientes |
| `bronze.erp_loc_a101` | ERP | País dos clientes |
| `bronze.erp_px_cat_g1v2` | ERP | Categorias e subcategorias de produtos |

### **Regras da Prata**
- Segue a mesma regra da Bronze: nome do sistema de origem + nome original da tabela, **sem renomear**. Assim fica fácil rastrear de qual tabela da Bronze cada tabela da Prata veio.
- **`<sistema_origem>_<entidade>`**
  - `<sistema_origem>`: nome do sistema de origem (`crm` ou `erp`).
  - `<entidade>`: nome exato da tabela no sistema de origem.
  - Exemplo: `silver.crm_cust_info` → clientes do CRM, já limpos e padronizados.

A Prata tem as mesmas seis tabelas da Bronze, no schema `silver`.

### **Regras da Ouro**
- Os nomes devem ser claros e alinhados ao negócio, começando pelo prefixo da categoria.
- **`<categoria>_<entidade>`**
  - `<categoria>`: papel do objeto no modelo, como `dim` (dimensão) ou `fact` (fato).
  - `<entidade>`: nome descritivo, alinhado ao domínio do negócio (ex.: `customers`, `products`, `sales`).
  - Exemplos:
    - `gold.dim_customers` → view de dimensão com os dados de clientes (CRM + ERP integrados).
    - `gold.dim_products` → view de dimensão com os produtos e suas categorias.
    - `gold.fact_sales` → view de fatos com as transações de venda.

#### **Glossário de Prefixos**

| Prefixo | Significado | Exemplo(s) |
|---|---|---|
| `dim_` | Tabela/view de dimensão | `dim_customers`, `dim_products` |
| `fact_` | Tabela/view de fatos | `fact_sales` |
| `report_` | Tabela/view de relatório (reservado para uso futuro) | `report_customers`, `report_sales_monthly` |

## **Nomenclatura de Colunas**

### **Chaves Substitutas**
- Toda chave primária das dimensões usa o sufixo `_key`.
- **`<nome_da_entidade>_key`**
  - `<nome_da_entidade>`: entidade à qual a chave pertence.
  - `_key`: sufixo que indica que a coluna é uma chave substituta (*surrogate key*), gerada no próprio data warehouse e diferente do código que vem do sistema de origem.
  - Exemplos:
    - `customer_key` → chave substituta de `gold.dim_customers`.
    - `product_key` → chave substituta de `gold.dim_products`.
  - Na `gold.fact_sales`, essas mesmas colunas aparecem como chaves estrangeiras que ligam a venda às dimensões.

### **Colunas Técnicas**
- Toda coluna técnica começa com o prefixo `dwh_`, seguido de um nome que indique sua finalidade.
- **`dwh_<nome_da_coluna>`**
  - `dwh`: prefixo exclusivo para metadados gerados pelo sistema (não vêm da origem).
  - `<nome_da_coluna>`: nome descritivo da finalidade da coluna.
  - Exemplo: `dwh_create_date` → data e hora em que o registro foi carregado na camada Prata (preenchida automaticamente com `GETDATE()`).

## **Stored Procedures**

- Toda stored procedure usada para carregar dados segue o padrão:
- **`load_<camada>`**, criada dentro do schema da própria camada.
  - `<camada>`: camada que está sendo carregada (`bronze` ou `silver`).
  - Exemplos:
    - `bronze.load_bronze` → carrega os CSVs na camada Bronze.
    - `silver.load_silver` → carrega a camada Prata a partir da Bronze.
  - A camada Ouro não tem procedure de carga, porque é formada por views.
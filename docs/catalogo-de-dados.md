# **Catálogo de Dados**

Este documento descreve as tabelas e colunas da camada **Ouro (Gold)** do data warehouse, o modelo analítico (esquema estrela) consumido por relatórios e análises. As views são definidas em [`scripts/gold/ddl_gold.sql`](../scripts/gold/ddl_gold.sql) e calculadas na leitura a partir da camada Prata (`silver`).

## **Sumário**

- [Visão geral](#visão-geral)
- [gold.dim_customers](#golddim_customers)
- [gold.dim_products](#golddim_products)
- [gold.fact_sales](#goldfact_sales)
- [Relacionamentos](#relacionamentos)

---

## **Visão geral**

| Objeto | Tipo | Granularidade | Fontes (Prata) |
|---|---|---|---|
| `gold.dim_customers` | Dimensão | 1 linha por cliente | `crm_cust_info`, `erp_cust_az12`, `erp_loc_a101` |
| `gold.dim_products` | Dimensão | 1 linha por produto ativo | `crm_prd_info`, `erp_px_cat_g1v2` |
| `gold.fact_sales` | Fato | 1 linha por item de pedido | `crm_sales_details` (ligada às duas dimensões) |

---

## **gold.dim_customers**

- **Finalidade:** dados cadastrais dos clientes, integrando informações do CRM (cadastro) e do ERP (data de nascimento, gênero e país).
- **Granularidade:** uma linha por cliente (`customer_id`).

| Coluna | Tipo | Descrição |
|---|---|---|
| `customer_key` | BIGINT | Chave substituta da dimensão (número sequencial gerado na view). É a chave estrangeira usada em `fact_sales`. |
| `customer_id` | INT | Identificador numérico do cliente no CRM. |
| `customer_number` | VARCHAR(50) | Código alfanumérico do cliente (ex.: `AW00011000`). Liga o CRM às tabelas do ERP. |
| `first_name` | VARCHAR(50) | Primeiro nome do cliente, sem espaços nas pontas. |
| `last_name` | VARCHAR(50) | Sobrenome do cliente, sem espaços nas pontas. |
| `country` | VARCHAR(50) | País do cliente, padronizado (ex.: `Germany`, `United States`). `n/a` quando não informado; `NULL` se o cliente não existir no ERP de localização. |
| `marital_status` | VARCHAR(50) | Estado civil: `Single`, `Married` ou `n/a`. |
| `customer_gender` | VARCHAR | Gênero: `Male`, `Female` ou `n/a`. Usa o CRM e, se ele for `n/a`, complementa com o ERP. |
| `birth_date` | DATE | Data de nascimento. `NULL` quando ausente ou fora do intervalo aceito (1924-01-01 a 2024-12-31). |
| `create_date` | DATE | Data em que o cliente foi cadastrado no CRM. |

---

## **gold.dim_products**

- **Finalidade:** dados dos produtos **ativos** (sem data de fim) com sua categoria e subcategoria.
- **Granularidade:** uma linha por produto ativo (`product_number`).

| Coluna | Tipo | Descrição |
|---|---|---|
| `product_key` | BIGINT | Chave substituta da dimensão. É a chave estrangeira usada em `fact_sales`. |
| `product_id` | INT | Identificador numérico do produto no CRM. |
| `product_number` | VARCHAR(50) | Código do produto (ex.: `FR-R92B-58`), igual ao código usado nas vendas. |
| `product_name` | VARCHAR(50) | Nome do produto. |
| `product_category_id` | VARCHAR(50) | Código da categoria (ex.: `CO_RF`), extraído da chave original do produto. |
| `product_category` | VARCHAR(50) | Categoria (ex.: `Bikes`, `Components`, `Clothing`, `Accessories`). |
| `product_subcategory` | VARCHAR(50) | Subcategoria (ex.: `Road Frames`). |
| `maintenance` | VARCHAR(50) | Indica se o produto exige manutenção: `Yes` ou `No`. |
| `product_cost` | INT | Custo do produto. `0` quando não informado na origem. |
| `product_line` | VARCHAR(50) | Linha do produto: `Road`, `Mountain`, `Touring`, `Other sales` ou `n/a`. |
| `start_date` | DATE | Data de início de vigência do produto. |
| `end_date` | DATE | Data de fim de vigência. Sempre `NULL` nesta view, porque só os produtos ativos são exibidos. |

---

## **gold.fact_sales**

- **Finalidade:** transações de vendas, para análises de receita, quantidade e preço por cliente, produto e período.
- **Granularidade:** uma linha por item de pedido. Um mesmo `order_number` pode aparecer em mais de uma linha.

| Coluna | Tipo | Descrição |
|---|---|---|
| `order_number` | VARCHAR(50) | Número do pedido (ex.: `SO43697`). |
| `product_key` | BIGINT | Chave estrangeira para `gold.dim_products.product_key`. |
| `customer_key` | BIGINT | Chave estrangeira para `gold.dim_customers.customer_key`. |
| `order_date` | DATE | Data do pedido. Quando inválida na origem, é recuperada como `ship_date - 7 dias` (regra válida em 100% das vendas com data correta). |
| `ship_date` | DATE | Data de envio. |
| `due_date` | DATE | Data de vencimento. |
| `sales` | INT | Valor da venda. Recalculado como `quantity x price` quando nulo, não positivo ou inconsistente. |
| `quantity` | INT | Quantidade de itens vendidos. |
| `price` | INT | Preço unitário. Quando nulo ou não positivo, é calculado como `sales / quantity`. |

---

## **Relacionamentos**

```
dim_customers (1) ────< (N) fact_sales (N) >──── (1) dim_products
   customer_key                                      product_key
```

- Cada venda pertence a **um** cliente e a **um** produto. Um cliente ou produto pode ter **várias** vendas.
- As ligações são feitas por `LEFT JOIN`, então uma venda sem cliente ou sem produto ativo ficaria com a chave `NULL` em vez de ser descartada. Hoje todas as vendas encontram cliente e produto (validado nos dados).

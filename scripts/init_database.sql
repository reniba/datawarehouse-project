/*
=============================================================
Criação do Banco de Dados e dos Schemas (PostgreSQL)
=============================================================
Objetivo do script:
    Este script cria um novo banco de dados chamado 'datawarehouse'.
    Se o banco já existir, ele é apagado e recriado. Em seguida, o script
    cria três schemas dentro do banco: 'bronze', 'silver' e 'gold'.

Como executar (o PostgreSQL não tem o comando USE):
    PARTE 1 -> rodar conectado ao banco 'postgres' (banco padrão).
    PARTE 2 -> rodar conectado ao banco 'datawarehouse', recém-criado.

ATENÇÃO:
    Rodar este script apaga o banco 'datawarehouse' inteiro, caso ele exista.
    Todos os dados serão perdidos permanentemente. Tenha cuidado e
    garanta que existe backup antes de executar.
*/


-- =============================================================
-- PARTE 1: executar conectado ao banco 'postgres'
-- =============================================================

-- Apaga o banco se ele existir, derrubando conexões abertas
-- (WITH (FORCE) exige PostgreSQL 13 ou superior)
DROP DATABASE IF EXISTS datawarehouse WITH (FORCE);

-- Cria o banco 'datawarehouse'
CREATE DATABASE datawarehouse;


-- =============================================================
-- PARTE 2: executar conectado ao banco 'datawarehouse'
-- =============================================================

-- Cria os schemas de cada camada
CREATE SCHEMA IF NOT EXISTS bronze;
CREATE SCHEMA IF NOT EXISTS silver;
CREATE SCHEMA IF NOT EXISTS gold;
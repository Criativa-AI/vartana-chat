# Informações de Acesso e Configuração - VPS Hetzner

Este documento consolida as informações principais de acesso e configuração da VPS para deploy dos projetos via Docker.

## 📡 Acessos Principais

* **IP IPv4:** `135.181.101.28`
* **IP IPv6:** `2a01:4f9:c013:3b04::/64`
* **Usuário:** `root`
* **Senha Web Console (Temporária/Fallback):** `Vartana$2026Server!`
* **Autenticação Padrão:** Chave SSH

### 🔑 Como conectar via SSH

O acesso primário deve ser feito usando a chave SSH gerada e já inserida no arquivo `authorized_keys` da VPS.

Para acessar diretamente do seu terminal, execute:

```bash
ssh -i ~/.ssh/hetzner_key root@135.181.101.28
```

> **Aviso:** A chave privada local está em `~/.ssh/hetzner_key`. Certifique-se de realizar backup desse arquivo de chave SSH caso deseje acessar de outra máquina no futuro. A chave pública atrelada à VPS é:
> `ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILr5/omKisb5d6BOfhO4z8gCdvY3SujDNd0DQO9qm/zn vartana-project`

### 👥 Acesso para outros Desenvolvedores

Se outro desenvolvedor precisar acessar a VPS a partir de uma máquina diferente, existem duas formas principais:

**Opção 1 (Recomendada e mais segura - Chave SSH Própria):**

1. O desenvolvedor deve gerar uma chave SSH na própria máquina dele (ex: `ssh-keygen -t ed25519`).
2. Ele deve enviar a você o conteúdo do arquivo da chave pública gerada (o arquivo com final `.pub`).
3. Você acessa a VPS e adiciona essa chave pública ao arquivo `/root/.ssh/authorized_keys` da VPS.
4. Após isso, o desenvolvedor poderá acessar a VPS sem senha usando a chave dele (`ssh root@135.181.101.28`).

**Opção 2 (Acesso por Senha):**
O desenvolvedor pode acessar informando a senha root atualizada (`Vartana$2026Server!`). Ao rodar o comando genérico `ssh root@135.181.101.28`, se a chave SSH não for encontrada na máquina dele, o terminal pedirá a senha. (Lembrando que o uso contínuo de senha é menos seguro que o de chaves SSH e o ideal é adicionar chaves individuais).

---

## 💻 Ambiente Configurado

O sistema atual rodando na VPS é o **Ubuntu 24.04**. As seguintes dependências e ferramentas foram devidamente instaladas, atualizadas e configuradas para deploys com Docker:

* **Docker Motor de contêineres e Buildx:** Instalado nativamente e rodando ativamente.
* **Docker Compose (Plugin nativo):** Pronto para subida em pilha de contêineres. Execute com `docker compose up -d`.
* **Git:** Instalado e pronto para o clone de repositórios privados ou públicos.
* **UFW (Uncomplicated Firewall):** Foi ativado para controle de tráfego de rede básico.

### 🛡️ Portas Liberadas (Firewall)

* **22** (TCP) - OpenSSH (acesso remoto)
* **80** (TCP) - Tráfego HTTP (para acesso ao proxy reverso ou aplicações expostas diretas)
* **443** (TCP) - Tráfego HTTPS (para comunicação criptografada externa via SSL/TLS)

*(Nota: Se alguma aplicação precisar de uma porta de rede específica exposta ao mundo, será necessário adicionar permissão no firewall executando `ufw allow NUMERO_DA_PORTA`).*

---

## 📁 Estrutura de Pastas de Projeto

A pasta base inicial para alocar seus projetos (via Git Clone, por exemplo) está estabelecida no diretório `home` do usuário `root`:

* **Diretório Raiz dos Projetos:** `/root/projetos/` (também acessível por `~/projetos/`)

Para subir um novo projeto:

1. Acesse o servidor e a pasta: `cd ~/projetos/`
2. Clone seu projeto Git lá dentro: `git clone https://...`
3. Entre na pasta clonada e execute seu `docker compose up -d` ou construa o build com Dockerfile.

User root
Password LgLLTncwe74J

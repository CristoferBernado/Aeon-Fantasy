# Aeon Fantasy - Câmera Isométrica 3D & MMORPG Core Systems

Protótipo completo de RPG de Ação 3D com câmera isométrica estilo *Ragnarok Online* e *MU Online*, desenvolvido na **Godot Engine 4**.

---

## 🎮 Funcionalidades Principais

### 📷 Câmera & Navegação
- **Câmera Seguidora Estilo RO / MU**: Câmera isométrica em 45° que segue suavemente o personagem (`lerp`), mantendo-o sempre centralizado na tela.
- **Rotação de Câmera**: Passos discretos de 90° acionados via teclado (`Q` / `E` / `Seta Esquerda` / `Seta Direita`).
- **Movimentação Point-and-Click**: Clique no terreno 3D para navegar com deslizamento em colisores (`move_and_slide`) e indicador visual animado no chão.
- **Mapa Amplo Expansion (120m x 120m)**: Terreno expandido com navegação via `NavigationMesh` e diversos mobs e árvores espalhados.

### 💎 Sistema de Joias de Refinamento (+0 a +9)
- **Jewel of Simplicity**:
  - Utilizada para refinar equipamentos de **+0 até +6**.
  - Concede um aumento gradual nos atributos do item (+0.833% por nível, atingindo **+5.0% no +6**).
- **Jewel of Ethrel**:
  - Utilizada para refinar equipamentos de **+6 até +9**.
  - Concede um aumento gradual adicional (+1.666% por nível, atingindo **+10.0% no +9**).
- **Mecânica por Drag & Drop ou Clique Direito**: Arraste a joia sobre um equipamento no inventário para refiná-lo com efeito sonoro/visual de popup reluzente.

### 📜 Requisitos de Atributos por Classe e Raridade
- Requisitos de atributos base (`STR`, `AGI`, `VIT`, `INT`, `DEX`, `LUK`) vinculados aos arquétipos das classes do jogo:
  - **Drakenyel** (STR / VIT): Espadas pesadas, Escudos e Armaduras de ferro.
  - **Birdyel** (AGI / DEX): Botas de Mercenário, Luvas e trajes leves.
  - **Nekunyel** (INT / DEX): Cajados e itens mágicos/místicos.
  - **Elfenyel** (DEX / LUK): Arcos e trajes de precisão.
- **Escala por Raridade**: Atributos requeridos escalam proporcionalmente à raridade do item (**Comum** < **Excelente** < **Ancient** < **★ GALÁCTICO ★**).
- **Validação ao Equipar**: Tentativas de vestir um item sem os atributos necessários disparam o aviso em vermelho `"Requer: STR 30!"` e bloqueiam a ação. O inspetor exibe os requisitos em **Verde** (satisfeito) ou **Vermelho** (faltante).

### 🗺️ Minimapa Radar (Canto Superior Direito)
- Radar circular/retangular em tempo real com identificação colorida:
  - 🟢 **Ponto Verde**: Posição atual do jogador.
  - 🔴 **Pontos Vermelhos**: Mobs vivos no mapa.
  - 🟡 **Pontos Dourados**: Itens dropados no chão.
  - 🔵 **Pontos Ciano**: NPCs do mapa (Vendedor e Ferreiro).

### ⚔️ Sistema de Combate & Fórmulas MMORPG
- **Trava de Mira & Ataque por ASPD**: Clique simples aproxima o personagem; clique duplo inicia o ataque contínuo. A velocidade de ataque é **estritamente vinculada aos status do personagem** (ASPD / AGI / DEX), impedindo aceleração por cliques repetidos.
- **Cálculo de Combate Completo**: Fórmulas matemáticas de Precisão vs Esquiva (`HIT` vs `FLEE`), Taxa Crítica (`CRIT`), **Hard DEF** (equipamentos) e **Soft DEF** (VIT).
- **Popups Numéricos de Dano Ampliados (Estilo RO)**: Danos brancos, críticos em amarelo dourado (`★ CRÍTICO!`), esquivas (`MISS`) e dano recebido pelo jogador em vermelho.

### 🎒 Mochila, Equipamentos e Drag & Drop
- **Janela de Inventário (`[I]`) e Paper Doll (`[O]`)**: Mochila com 35 slots e aba de equipamentos ativas.
- **Janelas Flutuantes e Arrastáveis**: Mochila, Atributos, Loja NPC e Ferreiro podem ser arrastados pela tela clicando em seus cabeçalhos, respeitando os limites da resolução.
- **Drag & Drop com o Mouse**: Clique com o botão esquerdo e arraste um item da mochila para fora da janela para jogá-lo no chão.
- **Clique Direito Inteligente**: Equipa consumíveis ou desequipa itens de acordo com o contexto.
- **Limite de Peso Dinâmico**: $\text{Capacidade} = 2000.0 + (\text{STR} \times 30.0)\text{ kg}$.

### 💰 Sistema de Moedas (Éons & Astris)
- **Éons (`E`)**: Ouro principal do jogo obtido derrotando mobs (sacos de Éons em quantia proporcional ao nível do mob) e utilizado em compras e reparos em NPCs.
- **Astris (`A`)**: Moeda premium (Cash) do jogo.
- Duas barras dedicadas no topo do inventário exibem os saldos em tempo real (`🪙 E: 500 Éons | 💎 A: 50 Astris`).

### 📦 Loot Drop no Chão 3D & Barra de Espaço
- **Loot Drop no Chão 3D (Estilo MU Online)**: Mobs dropam itens no chão 3D com rotação suave e rótulo flutuante `Label3D` contendo o nome e cor da raridade.
- **Despawn Automático (20 Segundos)**: Itens no chão somem automaticamente após 20 segundos.
- **Coleta via Barra de Espaço (`[Espaço]`)**: Pressionar a barra de espaço coleta automaticamente o item no chão mais próximo do jogador.
- **UUID Único Anti-Dupe**: Cada item possui um Serial UUID interno único para evitar duplicação em futuros sistemas de Trade entre jogadores.

### 🔨 Sistema de Durabilidade & Ferreiro (NPC)
- **Durabilidade Escalável por Raridade**:
  - **Comum**: Max 50 | **Excelente**: Max 80 | **Ancient**: Max 120 | **Galáctico**: Max 200.
- **Penalidade de Item Quebrado (80% Stat Loss)**: Se a durabilidade de um equipamento chega a $0$, o item é marcado como `🔴 QUEBRADO` e perde **80% de seus bônus de status** (oferecendo apenas 20% de eficácia).
- **Degradação em Combate**: Armas perdem durabilidade ao atacar; armaduras e escudos perdem durabilidade ao receber golpes.
- **NPC Ferreiro (`Vector3(-5, 0, 5)`)**: Janela da **Oficina do Ferreiro** com opções de **Reparar Item Selecionado** ou **✨ REPARAR TODOS OS EQUIPAMENTOS ✨** em lote por Éons.
- **Fechamento Automático de Janelas**: Mover o personagem ou interagir com o mapa fecha automaticamente qualquer janela de NPC aberta.

---

## 📁 Estrutura do Projeto

```text
Aeon Fantasy/
├── assets/                  # Texturas, spritesheets e recursos gráficos (tree_pine.png, etc.)
├── scenes/
│   ├── main.tscn            # Cena principal 3D (Cenário 120x120, Mobs, NPCs e Terreno)
│   ├── mob.tscn             # Cena do Monstro (Malha 3D, Colisor, Anel de Mira e Label HP)
│   ├── dropped_item.tscn    # Item dropado no chão 3D com rótulo e rotação
│   ├── npc_shop.tscn        # NPC Vendedor de Equipamentos (Loja de Éons & Joias)
│   ├── npc_blacksmith.tscn  # NPC Ferreiro (Oficina de Reparos)
│   ├── tree_pine.tscn       # Objeto de cenário 2.5D (Pinheiro com colisor cilíndrico)
│   └── click_marker.tscn    # Indicador visual de clique no chão
├── scripts/
│   ├── main.gd              # Gerenciador do Mapa, Raycast 3D, Respawn de Mobs e NPCs
│   ├── camera_controller.gd # Câmera isométrica seguidora e rotação 90°
│   ├── player.gd            # Movimentação, combate ASPD, trava de alvos e degradação
│   ├── mob.gd               # Monstro IA (Patrulha, Perseguição, Ataque, Morte e Loot Drops de Éons)
│   ├── dropped_item.gd      # Item no chão 3D, timer de 20s e coleta por proximidade/Espaço
│   ├── npc_shop.gd          # Script do NPC Vendedor (Venda de Joias Simplicity e Ethrel)
│   ├── npc_blacksmith.gd    # Script do NPC Ferreiro
│   ├── character_attributes.gd # Estatísticas do personagem, fórmulas RO e recálculo
│   ├── item_data.gd         # Estrutura de dados de itens (Refinamento +0~+9, Requisitos de Classe, Joias)
│   ├── inventory_manager.gd # Mochila, Carteira de Éons/Astris, Equipamentos, Validações e Refinamento
│   ├── hud_controller.gd    # Interface HUD completa (Janelas flutuantes, Requisitos, Loja, Ferreiro)
│   ├── damage_popup.gd      # Popups numéricos 3D animados estilo RO
│   └── click_marker.gd      # Animação do indicador de clique no chão
├── project.godot            # Configurações do projeto na Godot Engine
├── README.md                # Visão geral e guia de funcionalidades
└── CONTEXT.md               # Arquitetura técnica e detalhes de implementação
```

---

## 🚀 Como Executar o Projeto

1. Abra a **Godot Engine 4.3+**.
2. Importe o projeto selecionando o arquivo `project.godot`.
3. Pressione **F5** para executar a cena principal (`res://scenes/main.tscn`).

---

## ⌨️ Controles

- **Botão Esquerdo do Mouse**:
  - No Chão: Move o personagem até o local clicado.
  - No Mob (1 Clique): Trava a mira e aproxima o jogador.
  - No Mob (2 Cliques): Trava a mira e inicia ataques automáticos contínuos (frequência ASPD).
  - No Item do Chão / NPC: Move até o objeto e interage / abre janela.
  - Arrastar Itens no Inventário: Arraste para fora da mochila para jogar o item no chão ou arraste uma **Jewel of Simplicity / Ethrel** sobre um equipamento para refiná-lo.
  - Arrastar Janelas da UI: Clique no cabeçalho das janelas (Mochila, Atributos, Loja, Ferreiro) para reposicioná-las.
- **Barra de Espaço (`[Espaço]`)**: Coleta automaticamente o item no chão mais próximo do jogador.
- **Botão Direito do Mouse**:
  - Na Mochila: Equipa o item, consome poção ou aplica joia de refinamento no item selecionado.
  - Nos Equipamentos: Desequipa o item e o devolve para a mochila.
- **Teclas `Q` / `Seta Esquerda`**: Gira a câmera 90° para a esquerda.
- **Teclas `E` / `Seta Direita`**: Gira a câmera 90° para a direita.
- **Tecla `C`**: Abre/Fecha a janela de **Atributos do Personagem**.
- **Tecla `I` ou `B`**: Abre/Fecha a **Mochila do Inventário**.
- **Tecla `O`**: Abre/Fecha a aba de **Equipamentos (Paper Doll)**.

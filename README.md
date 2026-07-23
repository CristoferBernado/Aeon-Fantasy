# Aeon Fantasy - Full 3D Action RPG & MMORPG Core Systems

Protótipo completo de RPG de Ação 3D com câmera livre 360º, modelos de personagem 3D em formato `.glb` com animações esqueléticas (Idle, Walk, Die), praça central Safe Zone e mecânicas MMORPG inspiradas em *Ragnarok Online* e *MU Online*, desenvolvido na **Godot Engine 4**.

---

## 🎮 Funcionalidades Principais

### 🧙‍♂️ Personagem 3D & Sistema Multi-Modelo de Animação
- **Troca Dinâmica de Modelos GLTF/GLB**:
  - **Parado (Idle)**: Exibe o modelo 3D [`assets/idle.glb`](file:///d:/Projeto/Aeon%20Fantasy/assets/idle.glb) executando animação de respiração/espera.
  - **Em Movimento (Walk)**: Oculta o modelo parado e ativa o modelo [`assets/catwalk.glb`](file:///d:/Projeto/Aeon%20Fantasy/assets/catwalk.glb) com animação em loop contínuo (`Animation.LOOP_LINEAR`) para caminhada fluida.
  - **Morte (Die)**: Ao zerar o HP, ativa o modelo [`assets/die.glb`](file:///d:/Projeto/Aeon%20Fantasy/assets/die.glb) com a animação de queda no chão (`Animation.LOOP_NONE`).
- **Cadência de Caminhada**: Velocidade de movimento ajustada para **$4.8\text{m/s}$** para sintonia perfeita com o ritmo da caminhada 3D.
- **Movimentação Contínua (Hold-to-Move)**: Mantenha o botão esquerdo do mouse pressionado para seguir o cursor continuadamente pelo mapa sem necessidade de cliques repetidos.

### 🏰 Cidade Central Safe Zone & Praça de Pedra
- **Praça de Paralelepípedo (`CobblestonePlaza`)**: Área central de $21\text{m} \times 19\text{m}$ em pedra trabalhada.
- **Perímetro de Cercas de Madeira (`SafeZoneFences`)**: Cerca de madeira detalhada com 4 cantos perfeitamente encaixados e 4 portões cardeais (Norte, Sul, Leste e Oeste) ladeados por postes ornamentais com lanternas de iluminação quente (`scenes/fence_post_gate.tscn`).
- **Árvores de Moldura**: Passagens dos portões totalmente livres de obstáculos para trânsito fluido.

### 🎥 Câmera Livre 360º em 3D
- **Rotação Livre via Botão Direito (RMB)**: Segure e arraste o botão direito do mouse para orbitar suavemente a câmera em **360º na horizontal (Yaw)** e inclinar entre **$15^\circ$ e $85^\circ$ na vertical (Pitch)**.
- **Controles Auxiliares de Câmera**:
  - **Scroll do Mouse**: Zoom In / Zoom Out ($8.0\text{m}$ a $28.0\text{m}$).
  - **Teclas `Q` / `E` / `Setas`**: Giros rápidos de $90^\circ$.
  - **Tecla `R`**: Reseta a câmera para o ângulo neutro de $45^\circ$.

### 🎒 HUD Equipamentos Simétricos, Inventário & Mercado NPC
- **Aba de Equipamentos 5x3**: Grade simétrica de 15 slots alinhada para 13 tipos de equipamento (capacete, vestuário, armas, escudo, botas, brincos, anéis, asas, pet, etc.).
- **Barras de Status Pré-Preenchidas**: Barras de HP, SP, EXP Base e EXP Classe inicializam 100% preenchidas.
- **Sistema de Raridade**: Comum, Excelente, Ancient e ★ GALÁCTICO ★.
- **NPC Vendedor e Ferreiro**: Compra, venda (drag & drop) com confirmação para itens raros e reparo de durabilidade de equipamentos.

---

## 🚀 Como Executar o Projeto

1. Abra a **Godot Engine 4.3+**.
2. Importe o projeto selecionando o arquivo `project.godot`.
3. Pressione **F5** para executar a cena principal (`res://scenes/main.tscn`).

---

## ⌨️ Controles

- **Botão Esquerdo do Mouse (LMB)**: Clique / Manter pressionado para Movimentação Contínua / Seleção de Alvo / Interação / Drag & Drop.
- **Botão Direito do Mouse (RMB + Arraste)**: **Rotação livre em 360º da Câmera (Yaw e Pitch)**.
- **Roda do Mouse (Scroll)**: Controla o Zoom da Câmera ($8.0\text{m}$ a $28.0\text{m}$).
- **Barra de Espaço (`[Espaço]`)**: Coleta automaticamente o item no chão mais próximo.
- **Teclas `Q` / `E` / `Setas`**: Rotação rápida em passos de $90^\circ$.
- **Tecla `R`**: Reseta o ângulo e inclinação da câmera.
- **Teclas `C`, `I`, `O`**: Janelas de Atributos, Mochila e Equipamentos.

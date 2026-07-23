# Aeon Fantasy - Full 3D Action RPG & MMORPG Core Systems

Protótipo completo de RPG de Ação 3D com câmera livre 360º, modelo de personagem 3D customizado em formato `.glb` e mecânicas MMORPG inspiradas em *Ragnarok Online* e *MU Online*, desenvolvido na **Godot Engine 4**.

---

## 🎮 Funcionalidades Principais

### 🧙‍♂️ Personagem 3D Heroico (`.glb`)
- **Malha 3D de Alta Qualidade**: Personagem 3D completo (`fantasy character 3d model.glb`) em escala heroica de **$2.6\times$**.
- **Ajuste de Física e Colisão**: Caixas de colisão 3D ajustadas em $2.4\text{m}$ de altura para movimentação precisa no ambiente 3D.
- **Animações e Combate**: Balanço de caminhada procedural e animação de golpe em arco com espada metálica reluzente e fagulhas de impacto 3D.

### 🎥 Câmera Livre 360º em 3D
- **Rotação Livre via Botão Direito (RMB)**: Segure e arraste o botão direito do mouse para orbitar suavemente a câmera em **360º na horizontal (Yaw)** e inclinar entre **$15^\circ$ e $85^\circ$ na vertical (Pitch)**.
- **Controles Auxiliares de Câmera**:
  - **Scroll do Mouse**: Zoom In / Zoom Out ($8.0\text{m}$ a $28.0\text{m}$).
  - **Teclas `Q` / `E` / `Setas`**: Giros rápidos de $90^\circ$.
  - **Tecla `R`**: Reseta a câmera para o ângulo neutro de $45^\circ$.

### 🏰 Terreno Elevado, Escadas e Bosses de Mapa
- **Platô Elevado ($Y = 3.0\text{m}$)**: Setor Nordeste com escada rebaixada de pedra para transição fluida.
- **👑 Saeron (BOSS Lv 35)**: Boss com $3500\text{ HP}$, malha $2.5\times$ maior e rótulo 3D flutuante com `no_depth_test` para visibilidade impecável em qualquer ângulo 3D.

### 🎒 Inventário, Equipamentos & Mercado NPC
- **Sistema de Raridade**: Comum, Excelente, Ancient e ★ GALÁCTICO ★.
- **NPC Vendedor e Ferreiro**: Compra, venda (drag & drop) com confirmação para itens raros e reparo de durabilidade.

---

## 🚀 Como Executar o Projeto

1. Abra a **Godot Engine 4.3+**.
2. Importe o projeto selecionando o arquivo `project.godot`.
3. Pressione **F5** para executar a cena principal (`res://scenes/main.tscn`).

---

## ⌨️ Controles

- **Botão Esquerdo do Mouse (LMB)**: Movimentação / Seleção de Alvo / Interação / Drag & Drop na UI.
- **Botão Direito do Mouse (RMB + Arraste)**: **Rotação livre em 360º da Câmera (Yaw e Pitch)**.
- **Roda do Mouse (Scroll)**: Controla o Zoom da Câmera ($8.0\text{m}$ a $28.0\text{m}$).
- **Barra de Espaço (`[Espaço]`)**: Coleta automaticamente o item no chão mais próximo.
- **Teclas `Q` / `E` / `Setas`**: Rotação rápida em passos de $90^\circ$.
- **Tecla `R`**: Reseta o ângulo e inclinação da câmera.
- **Teclas `C`, `I`, `O`**: Janelas de Atributos, Mochila e Equipamentos.

# Aeon Fantasy - Câmera Isométrica 3D & MMORPG Core Systems

Protótipo completo de RPG de Ação 3D com câmera isométrica estilo *Ragnarok Online* e *MU Online*, desenvolvido na **Godot Engine 4**.

---

## 🎮 Funcionalidades Principais

### 🏰 Terreno Elevado, Escada Rebaixada (Estilo RO) & Boss do Mapa
- **Plataforma Elevada ($Y = 3.0\text{m}$)**: Platô no setor Nordeste do mapa (`Vector3(35, 1.5, -35)`).
- **Escada Rebaixada com Degraus de Pedra**: Topo a $Y = 2.90\text{m}$ (abaixo do piso do platô $Y = 3.00\text{m}$) para transição contínua.
- **Bloqueio de Mobs nas Escadas**: Mobs e Bosses são impedidos de subir ou descer as escadas entre os andares, mantendo o jogador com 100% de liberdade de movimento.
- **👑 Saeron (BOSS Lv 35)**:
  - Nível 35, 3500 HP, malha $2.5\times$ maior, confinado ao platô elevado.
  - **Rótulo 3D Flutuante Acima da Cabeça**: `👑 Saeron (BOSS Lv 35)` posicionado em $Y = 2.85\text{m}$ com renderização nítida sem clipping de câmera, exibindo nome, nível e HP de forma perfeitamente legível.

### ⚔️ Animações Procedurais & Modelo 3D da Lâmina do Caçador
- **Mãos e Pés Harmonizados**: Pés e mãos na cor azul reluzente do corpo do personagem.
- **Passada Física de Pés e Mãos**: Balanço alternado de pés e mãos com pausa inteligente em colisões.
- **Espada 3D & Golpe de Corte**: Lâmina de aço reluzente metálico, guarda dourada e animação de corte em arco com fagulhas de impacto.

### 💥 Efeitos Visuais 3D para Mobs & Venda de Itens no NPC
- **Fumaça de Morte (Explosão Poof 3D)** & **Aura Amarela de Spawn**.
- **Venda de Itens ao NPC Vendedor (Drag & Drop)** com confirmação para raridades **Excelente**, **Ancient** e **★ GALÁCTICO ★**.

---

## 🚀 Como Executar o Projeto

1. Abra a **Godot Engine 4.3+**.
2. Importe o projeto selecionando o arquivo `project.godot`.
3. Pressione **F5** para executar a cena principal (`res://scenes/main.tscn`).

---

## ⌨️ Controles

- **Botão Esquerdo do Mouse**: Movimento / Seleção de alvos / Drag & Drop.
- **Scroll da Roda do Mouse**: Controla o Zoom da câmera (`8.0m` a `28.0m`).
- **Barra de Espaço (`[Espaço]`)**: Coleta automaticamente o item no chão mais próximo do jogador.
- **Botão Direito do Mouse**: Equipa consumíveis ou desequipa itens de acordo com o contexto.
- **Teclas `Q` / `E` / `Setas`**: Gira a câmera 90°.
- **Tecla `C`**: Janela de Atributos | **Tecla `I`**: Mochila | **Tecla `O`**: Equipamentos.

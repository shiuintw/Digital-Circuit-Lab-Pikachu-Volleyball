# Pikachu Volleyball

#### By Shiuintw (cy hsu)

>This is the final project of the course Digital Circuit Lab 114-1 in NYCU-CS. Finished at 2025/12/01.
>Reorganized at 2026/04/04

#### Statement

>The source code is once stolen by a person with malicious intension before its publicization.
>It is strongly prohibited to steal the code, modify by AI tools, and state it to be yours.

---

## Structure

>Top Module: The main logic is in `fp_pikachu_volleyball.v`\
>There are multiple mem files to store images data to be displayed on VGA.\
>Part of this and some other files are based on the sample codes of Lab10 in Digital Circuit Lab 114-1 in NYCU-CS.

## Description

### Rules

* The ball is always served at the middle above the net.
* Every time the ball touches the ground, it stalls for a while, returns to the serving point and the scoreboard is updated.
* The one getting 9 pts first is the winner.
* When Switch3 is down, the game start. Pull up and down again to restart the game when game set.

### How to play

* Btn3: Move left
* Btn2: (1)Jump(Longer you hold, higher it jumps(has height limit)、cannot double jump)(2)prone(when falling to the ground, press the button again to prone to save the ball)
* Btn1: Smash the ball
* Btn0: Move right
* Sw3 : Game start & restart
* Sw2 : opponent level: opponent can jump
* Sw1 : opponent level: opponent can smash the ball

## Demo

[Demo Video](https://youtu.be/2qXk5oPVNHU)

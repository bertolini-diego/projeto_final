        PUBLIC  __iar_program_start
        EXTERN  __vector_table

        SECTION .text:CODE:REORDER(2)
        
        ;; Keep vector table even if it's not referenced
        REQUIRE __vector_table
        
        THUMB

; System Control definitions
SYSCTL_BASE             EQU     0x400FE000
SYSCTL_RCGCGPIO         EQU     0x0608
SYSCTL_PRGPIO		EQU     0x0A08
SYSCTL_RCGCUART         EQU     0x0618
SYSCTL_PRUART           EQU     0x0A18
; System Control bit definitions
PORTA_BIT               EQU     000000000000001b ; bit  0 = Port A
PORTF_BIT               EQU     000000000100000b ; bit  5 = Port F
PORTJ_BIT               EQU     000000100000000b ; bit  8 = Port J
PORTN_BIT               EQU     001000000000000b ; bit 12 = Port N
UART0_BIT               EQU     00000001b        ; bit  0 = UART 0

; NVIC definitions
NVIC_BASE               EQU     0xE000E000
NVIC_EN1                EQU     0x0104
VIC_DIS1                EQU     0x0184
NVIC_PEND1              EQU     0x0204
NVIC_UNPEND1            EQU     0x0284
NVIC_ACTIVE1            EQU     0x0304
NVIC_PRI12              EQU     0x0430

; GPIO Port definitions
GPIO_PORTA_BASE         EQU     0x40058000
GPIO_PORTF_BASE    	EQU     0x4005D000
GPIO_PORTJ_BASE    	EQU     0x40060000
GPIO_PORTN_BASE    	EQU     0x40064000
GPIO_DIR                EQU     0x0400
GPIO_IS                 EQU     0x0404
GPIO_IBE                EQU     0x0408
GPIO_IEV                EQU     0x040C
GPIO_IM                 EQU     0x0410
GPIO_RIS                EQU     0x0414
GPIO_MIS                EQU     0x0418
GPIO_ICR                EQU     0x041C
GPIO_AFSEL              EQU     0x0420
GPIO_PUR                EQU     0x0510
GPIO_DEN                EQU     0x051C
GPIO_PCTL               EQU     0x052C

; UART definitions
UART_PORT0_BASE         EQU     0x4000C000
UART_FR                 EQU     0x0018
UART_IBRD               EQU     0x0024
UART_FBRD               EQU     0x0028
UART_LCRH               EQU     0x002C
UART_CTL                EQU     0x0030
UART_CC                 EQU     0x0FC8
;UART bit definitions
TXFE_BIT                EQU     10000000b ; TX FIFO full
RXFF_BIT                EQU     01000000b ; RX FIFO empty
BUSY_BIT                EQU     00001000b ; Busy


; PROGRAMA PRINCIPAL

__iar_program_start
        
main:   MOV R2, #(UART0_BIT)
	BL UART_enable ; habilita clock ao port 0 de UART

        MOV R2, #(PORTA_BIT)
	BL GPIO_enable ; habilita clock ao port A de GPIO
        
	LDR R0, =GPIO_PORTA_BASE
        MOV R1, #00000011b ; bits 0 e 1 como especiais
        BL GPIO_special

	MOV R1, #0xFF ; máscara das funções especiais no port A (bits 1 e 0)
        MOV R2, #0x11  ; funções especiais RX e TX no port A (UART)
        BL GPIO_select

	LDR R0, =UART_PORT0_BASE
        BL UART_config ; configura periférico UART0
        
        ;; R0 servirá de auxiliar em algumas sub-rotinas 
        ;; R1 servirá para receber e transmitir os dados
        ;; R2 não será utilizado
        ;; R3 servirá de auxiliar em algumas sub-rotinas
        ;; R4 servirá de auxiliar para passar de hexadecimal para decimal
        ;; R5 servirá para saber se o caractere é ou não uma operação matemática
        ;; R6 servirá de auxiliar para fazer a transformação de R4
        ;; R7 servirá para manter a operação matemática que será realizada
        ;; R8 servirá para retornar o resultado da operação matematica
        ;; R9 será o primeiro número digitado pelo usuário
        ;; R10 será o segundo número digitado pelo usuário e também como auxiliar para retornar o LR
        ;; R11 servirá de contador para saber quantos algarismos do número já foram (deve ser no máximo 4 algarismos) e também como auxiliar para retornar o LR
        ;; R12 servirá como número 10 para multiplicar (deslocar à esquerda) ou dividir (deslocar à direita)

        PUSH {R9}                       ; coloca um valor zero na pilha para poder usar no primeiro caractere
        MOV R8, #-1                     ; coloca um valor de -1 no R8, que contém o resultado, para saber que ele ainda não foi mexido
loop:
        BL Verify_UART_RX               ; verifica se há RX
        LDR R1, [R0]                    ; lê do registrador de dados da UART0 (recebe) R1 armazena o valor de tabela ASC do caractere
      
        BL Verify_Other_Signals         ; verifica se há sinais de +, -, * ou /, se tiver, entrará em outras sub-rotinas
        BL Verify_Equal_Sign            ; verifica se há um sinal de =, se tiver, entrará em outras sub-rotinas
        ;BL Verify_Valid_Digits         ; verificar se são caracteres válidos (0 a 9) não funcionou

        CMP R5, #1
        BEQ Is_Operation                ; se o R5 for igual a 1 então está sendo uma operação matemática, então pula para o Is_Operation
verified:       

        ADD R11, R11, #1                ; adiciona 1 no contador para saber quantos algarismos tem o número
        BL Limit_Four_Digits            ; verifica se já foram 4 digitos //// R11 for 5 e R5 for 0, volta pra tras
        BL Transform_Hexa_To_Decimal    ; transforma de hexa para decimal       
        BL Manage_Registers             ; faz a operação R4 = R4 + R6
        BL Move_To_Left                 ; move um dígito decimal a esquerda
        PUSH {R4}                       ; coloca R4 na pilha      
                               
Is_Operation:                           ; quando for uma operação matemática pular pra cá    
        MOV R5, #0                      ; zera a indicação de que é uma operação matemática

back:           
        BL Verify_UART_TX               ; verifica se há TX
        STR R1, [R0]                    ; escreve no registrador de dados da UART0 (transmite)
        
        BL Verify_End                   ; verifica se chegou no fim, ou seja, coloca os algarismos na pilha
        BL Do_The_End_Operation         ; faz a operação final de tirar da pilha e colocar no R1
        
        CMP R8, #0                      ; verifica se R8 = 0, ou seja, quando chegar no zero da pilha, coloca R8 = -1, o que significa que acabou de transmitir 
        BEQ back                        ; se ainda não foi, significa que a pilha ainda está cheia e ele volta até que o R8 seja -1

        CMP R1, #0                      ; verifica se R1 = 0, ou seja, que o último valor da pilha, que é 0, foi para o R1, significando que acabou a transmissão
        IT EQ                           ; se o R1 = 0, então Z = 1 
        BLEQ Jump_Line                  ; faz o "\r" e o "\n"
        
        B loop
        
; SUB-ROTINAS

;----------
; UART_enable: habilita clock para as UARTs selecionadas em R2
; R2 = padrão de bits de habilitação das UARTs
; Destrói: R0 e R1
UART_enable:
        LDR R0, =SYSCTL_BASE
	LDR R1, [R0, #SYSCTL_RCGCUART]
	ORR R1, R2 ; habilita UARTs selecionados
	STR R1, [R0, #SYSCTL_RCGCUART]

waitu	LDR R1, [R0, #SYSCTL_PRUART]
	TEQ R1, R2 ; clock das UARTs habilitados?
	BNE waitu

        BX LR
        
; UART_config: configura a UART desejada
; R0 = endereço base da UART desejada
; Destrói: R1
UART_config:
        LDR R1, [R0, #UART_CTL]
        BIC R1, #0x01 ; desabilita UART (bit UARTEN = 0)
        STR R1, [R0, #UART_CTL]

        ; clock = 16MHz, baud rate = 14400 bps
        MOV R1, #69  ; BRD = 16.000.000 / (16 * 14.400) = 69,4444          104
        STR R1, [R0, #UART_IBRD]
        MOV R1, #28   ; FBRD = integer(0,4444 * 64 + 0.5) = 28             11
        STR R1, [R0, #UART_FBRD]
        
        ; 8 bits, 1 stop, no parity, FIFOs disabled, no interrupts = #0x60 = 0110 0000
        ; 7 bits de dados, paridade par e 1 bit de parada.
        MOV R1, #01000110b    ; #0x46
        STR R1, [R0, #UART_LCRH]
        
        ; clock source = system clock
        MOV R1, #0x00
        STR R1, [R0, #UART_CC]
        
        LDR R1, [R0, #UART_CTL]
        ORR R1, #0x01 ; habilita UART (bit UARTEN = 1)
        STR R1, [R0, #UART_CTL]

        BX LR

; Verify_UART_RX: verifica se há algo querendo ser transmitido ao emulador do terminal (transmissão RX)
Verify_UART_RX:
        LDR R2, [R0, #UART_FR] ; status da UART
        TST R2, #RXFF_BIT ; receptor cheio?
        BEQ Verify_UART_RX
        BX LR

; Verify_UART_TX: verifica se há algo querendo ser transmitido ao Kit (transmissão TX)
Verify_UART_TX:
        LDR R2, [R0, #UART_FR] ; status da UART
        TST R2, #TXFE_BIT ; transmissor vazio?
        BEQ Verify_UART_TX
        BX LR       

; Verify_Valid_Digits:       
Verify_Valid_Digits:

        ;CMP R5, #1
        ;BEQ verified

        ;CMP R1, #'0'
        ;BEQ verified
        
        ;CMP R1, #'1'
        ;BEQ verified
        
        ;CMP R1, #'2'
        ;BEQ verified
        
        ;CMP R1, #'3'
        ;BEQ verified
        
        ;CMP R1, #'4'
        ;BEQ verified
        
        ;CMP R1, #'5'
        ;BEQ verified
        
        ;CMP R1, #'6'
        ;BEQ verified
        
        ;CMP R1, #'7'
        ;BEQ verified
        
        ;CMP R1, #'8'
        ;BEQ verified
        
        ;CMP R1, #'9'
        ;BEQ verified
        
        ;BL loop
        ;BX LR
               
; Verify_Signals: verifica se o caractere de entrada foi algum sinal de operação diferente do igual(=)
Verify_Other_Signals:
        CMP R1, #'+'           ;testa se veio o sinal + (0x2b)        Z=1 quando R1 = 0x2b
        BEQ Store_Signal       ; se for igual a +, então devemos ir para outra subrotina

        CMP R1, #'-'           ;testa se veio o sinal - (0x2d)        Z=1 quando R1 = 0x2d
        BEQ Store_Signal       ; se for igual a -, então devemos ir para outra subrotina

        CMP R1, #'*'           ;testa se veio o sinal * (0x2a)        Z=1 quando R1 = 0x2a
        BEQ Store_Signal       ; se for igual a *, então devemos ir para outra subrotina

        CMP R1, #'/'           ;testa se veio o sinal / (0x2f)        Z=1 quando R1 = 0x2f
        BEQ Store_Signal       ; se for igual a /, então devemos ir para outra subrotina
        
        BX LR
        
; Store_Signal: armazena qual operação deverá ser feita
Store_Signal:
        MOV R10, LR                    ; R10 recebe o valor de LR
        MOV R5, #1                     ; indica que é uma operação matemática
        MOV R7, R1                     ; R7 mantém a informação de qual operação deverá ser feita
        BL Move_To_Right               ; move para a direita
        BL Store_First_Number          ; armazena o primeiro número
        MOV R11, #0                    ; zera o contador dos algarismos
        PUSH {R11}                     ; coloca zero na pilha, para começar a usar o R6 do segundo número, se não fizer isso dá erro no POP {R6} no loop lá em cima
        MOV LR, R10                    ; LR recebe seu valor de ínicio de R10
        BX LR
       
; Verify_Equal_Sign:  verifica se o caractere de entrada é o igual 
Verify_Equal_Sign:
        CMP R1, #'='                       ; testa se veio o sinal = (0x3d)        Z=1 quando R1 = 0x3
        BEQ Do_Operation
        BX LR

; Do_Operation: faz a operação matemática e coloca em R8
Do_Operation:
        MOV R11, LR
        MOV R5, #1                         ; indica que é uma operação matemática
        BL Move_To_Right
        BL Store_Second_Number             ; armazena o segundo número
        BL Select_Operation                ; executa a operação matemática
        BL Clean_Operation                 ; zera o R7
        MOV LR, R11
        POP {R11}
        MOV R11, #0                        ; zera o contador dos algarismos
        PUSH {R11}
        BX LR
 
; Select_Operation: direciona para fazer a operação matemática, seja ela +,-,* ou /       
Select_Operation:
        
        CMP R7, #'+'                       ; testa se veio o sinal + (0x2b)        Z=1 quando R1 = 0x2b
        BEQ Sum_Operation                  ; se for igual a +, então devemos ir para outra subrotina

        CMP R7, #'-'                       ; testa se veio o sinal - (0x2d)        Z=1 quando R1 = 0x2d
        BEQ Subtraction_Operation          ; se for igual a -, então devemos ir para outra subrotina

        CMP R7, #'*'                       ; testa se veio o sinal * (0x2a)        Z=1 quando R1 = 0x2a
        BEQ Multiplication_Operation       ; se for igual a *, então devemos ir para outra subrotina

        CMP R7, #'/'                       ; testa se veio o sinal / (0x2f)        Z=1 quando R1 = 0x2f
        BEQ Division_Operation             ; se for igual a /, então devemos ir para outra subrotina
        
        BX LR
     
; Sum_Operation: direciona para fazer a soma
Sum_Operation:
        PUSH {LR}
        ADD R8, R9, R10           ; coloca em R8 (que é pra mandar por TX) a soma do primeiro valor R9 ao segundo valor R10
        POP {LR}
        BX LR
        
; Subtraction_Operation: direciona para fazer a subtração
Subtraction_Operation:
        PUSH {LR}
        ;; se o resultado for negativo, colocar um menos na frente do resultado
        SUB R8, R9, R10           ; coloca em R8 (que é pra mandar por TX) a subtração do primeiro valor R9 pelo segundo valor R10
        POP {LR}
        BX LR

; Multiplication_Operation: direciona para fazer a multiplicação
Multiplication_Operation:
        PUSH {LR}
        MUL R8, R9, R10           ; coloca em R8 (que é pra mandar por TX) a multiplicação do primeiro valor R9 pelo segundo valor R10
        POP {LR}
        BX LR

; Division_Operation: direciona para fazer a divisão
Division_Operation:
        PUSH {LR}
        SDIV R8, R9, R10          ; coloca em R8 (que é pra mandar por TX) a divisão do primeiro valor R9 pelo segundo valor R10
        POP {LR}
        BX LR

; Tranform_Hexa_To_Decimal: transforma o valor que veio da tabela ASC (em hexadecimal) em decimal
Transform_Hexa_To_Decimal:
        PUSH {R0}
        MOV R0, #0x30             ; R0 recebe o valor de 30, que será usado para conversão de hexa em decimal (tabela ASC)               
        SUB R4, R1, R0            ; R4 = R1 (valor que foi recebido na UART) - #0x30
        POP {R0}
        BX LR
             
; Manage_Registers: coordena operações importantes para colocar valores da tabela ASC nos registradores     
Manage_Registers:
        POP {R6}                  ; colocar em R6 o valor da pilha
        ADD R4, R4, R6            ; R4 = R4 + R6
        BX LR

; Move_To_Left: move um dígito decimal a esquerda
Move_To_Left:
        PUSH {R0}
        MOV R12, #10              ; pega um registrador qualquer para fazer a multiplicação por 10
        MOV R0, R12               ; R0 = R12
        MULS R4, R4, R0           ; multiplica o R4 por 10, deslocando um número decimal a esquerda
        POP {R0}
        BX LR
        
; Move_To_Right: move um dígito decimal a direita
Move_To_Right:
        SDIV R4, R4, R12          ; divide o R4 por 10    
        BX LR
        
; Store_First_Number: armazena o primeiro número em R9  
Store_First_Number:
        MOV R11, LR               ; coloca em R11 o valor de LR (R11 será zerado mesmo)
        MOV R9, R4                ; coloca esse resultado em R9, que será o primeiro número
        BL Clean_Stack            ; limpa a pilha 
        BL Clean_Registers        ; limpa o R4 e o R6
        MOV LR, R11
        BX LR
        
; Store_Second_Number: armazena o segundo número em R10
Store_Second_Number:
        PUSH {LR}
        MOV R10, R4               ; coloca esse resultado em R10, que será o segundo número
        BL Clean_Registers        ; limpa o R4 e o R6
        POP {LR}
        BX LR
        
; Clean_Stack: limpa a pilha depois que foi feita a operação matemática
Clean_Stack:
        POP {R12}                 ; R12 = conteúdo da pilha
        MOV R12, #0               ; R12 = 0
        BX LR
      
; Clean_Registers: limpa os valores de R4 e R6 para poder usá-los na formação do segundo número     
Clean_Registers:
        PUSH {LR}
        MOV R4, #0                ; zera o valor de R4
        MOV R6, #0                ; zera o valor de R6
        POP {LR}
        BX LR

; Clean_Operation: limpa a operação matemática
Clean_Operation:
        MOV R7, #0                ; zera o valor armazenado em R7, ou seja, limpa a operação matemática
        BX LR
        
; Limit_Four_Digits:        
Limit_Four_Digits:
        CMP R11, #5
        BEQ jump_now
        BX LR
        
jump_now:
        PUSH {R1}
        MOV R1, #1
        SUB R11, R11, R1
        POP {R1}
        CMP R5, #0
        BEQ loop
        BX LR
        
        
; Verify_End: verifica se chegou no final, ou seja, verifica se o último valor de R1 é o "=", se for
; então devemos converter o resultado final de acordo com a tabela ASC    
Verify_End:
        MOV R3, LR
        BL Was_Equal_Sign         ; verifica se o último valor de R1 é o =
jump:
        MOV LR, R3
        BX LR

; Was_Equal_Sign: Foi o sinal de igual
Was_Equal_Sign:
        CMP R1, #'='              ; testa o R1 tem o valor = (0x3d)        Z=1 quando R1 = 0x3
        BEQ Convert_To_ASC        ; se sim, Z=1 e entra na sub-rotina Convert_To_ASC
        BX LR
        
; Convert_To_ASC: converte para tabela ASC e coloca na pilha 
Convert_To_ASC:
        MOV R7, #10                               ; R7 = 10
        PUSH {R8}                                 ; R8 vai para pilha (2469 como exemplo)
        SDIV R8, R8, R7                           ; R8 = R8/10 (246)
        MOV R6, R8                                ; R6 = R8 (246)
        MUL R9, R8, R7                            ; R9 = R8*R7 (2460)
        POP {R8}                                  ; R8 recebe da pilha (2469)
        SUB R1, R8, R9                            ; R1 = R8 - R9 (9)
        MOV R7, #0x30                             ; R7 = 30
        ADD R1, R1, R7                            ; R1 = R1 + R7 (9 + 0x30)
        PUSH {R1}                                 ; R1 vai pra pilha (0x39)
        MOV R8, R6                                ; R8 = R6 (246)
        CMP R8, #0                                ; R8 já é zero?
        BEQ jump                                  ; se for, pula
        BL Convert_To_ASC                         ; se não for, volta ao começo da subrotina
        
; Do_The_End_Operation: Faz a operação final de tirar da pilha se R8 já for 0       
Do_The_End_Operation:
        CMP R8, #0
        BEQ Pop_To_R1
        BX LR
        
; Pop_To_R1: Coloca o conteúdo da pilha em R1       
Pop_To_R1:
        POP {R1}
        CMP R1, #0                                 ; quando chegar no zero da pilha, colocar -1 no R8
        BEQ Put_Minus_1_In_R8
        BX LR
        
; Put_Minus_1_In_R8: Coloca o valor de -1 no R8
Put_Minus_1_In_R8:
        MOV R8, #-1                                ; R8 = -1
        PUSH {R1}                                  ; R1 = 0
        BX LR

; Jump_Line: pula uma linha e volta para o começo dela
Jump_Line:
        PUSH {LR}
        PUSH {R1}
        MOV R1, #'\r'                              ; retornar ao início da linha
        BL Verify_UART_TX                          ; verifica se há TX
        STR R1, [R0]
        POP {R1}        
        PUSH {R1}
        MOV R1, #'\n'                              ; pular de linha
        BL Verify_UART_TX                          ; verifica se há TX
        STR R1, [R0]
        POP {R1}
        POP {LR}
        BX LR
        

; GPIO_special: habilita funcões especiais no port de GPIO desejado
; R0 = endereço base do port desejado
; R1 = padrão de bits (1) a serem habilitados como funções especiais
; Destrói: R2
GPIO_special:
	LDR R2, [R0, #GPIO_AFSEL]
	ORR R2, R1 ; configura bits especiais
	STR R2, [R0, #GPIO_AFSEL]

	LDR R2, [R0, #GPIO_DEN]
	ORR R2, R1 ; habilita função digital
	STR R2, [R0, #GPIO_DEN]

        BX LR

; GPIO_select: seleciona funcões especiais no port de GPIO desejado
; R0 = endereço base do port desejado
; R1 = máscara de bits a serem alterados
; R2 = padrão de bits (1) a serem selecionados como funções especiais
; Destrói: R3
GPIO_select:
	LDR R3, [R0, #GPIO_PCTL]
        BIC R3, R1
	ORR R3, R2 ; seleciona bits especiais
	STR R3, [R0, #GPIO_PCTL]

        BX LR
;----------

; GPIO_enable: habilita clock para os ports de GPIO selecionados em R2
; R2 = padrão de bits de habilitação dos ports
; Destrói: R0 e R1
GPIO_enable:
        LDR R0, =SYSCTL_BASE
	LDR R1, [R0, #SYSCTL_RCGCGPIO]
	ORR R1, R2 ; habilita ports selecionados
	STR R1, [R0, #SYSCTL_RCGCGPIO]

waitg	LDR R1, [R0, #SYSCTL_PRGPIO]
	TEQ R1, R2 ; clock dos ports habilitados?
	BNE waitg

        BX LR

; GPIO_digital_output: habilita saídas digitais no port de GPIO desejado
; R0 = endereço base do port desejado
; R1 = padrão de bits (1) a serem habilitados como saídas digitais
; Destrói: R2
GPIO_digital_output:
	LDR R2, [R0, #GPIO_DIR]
	ORR R2, R1 ; configura bits de saída
	STR R2, [R0, #GPIO_DIR]

	LDR R2, [R0, #GPIO_DEN]
	ORR R2, R1 ; habilita função digital
	STR R2, [R0, #GPIO_DEN]

        BX LR

; GPIO_write: escreve nas saídas do port de GPIO desejado
; R0 = endereço base do port desejado
; R1 = máscara de bits a serem acessados
; R2 = bits a serem escritos
GPIO_write:
        STR R2, [R0, R1, LSL #2] ; escreve bits com máscara de acesso
        BX LR

; GPIO_digital_input: habilita entradas digitais no port de GPIO desejado
; R0 = endereço base do port desejado
; R1 = padrão de bits (1) a serem habilitados como entradas digitais
; Destrói: R2
GPIO_digital_input:
	LDR R2, [R0, #GPIO_DIR]
	BIC R2, R1 ; configura bits de entrada
	STR R2, [R0, #GPIO_DIR]

	LDR R2, [R0, #GPIO_DEN]
	ORR R2, R1 ; habilita função digital
	STR R2, [R0, #GPIO_DEN]

	LDR R2, [R0, #GPIO_PUR]
	ORR R2, R1 ; habilita resitor de pull-up
	STR R2, [R0, #GPIO_PUR]

        BX LR

; GPIO_read: lê as entradas do port de GPIO desejado
; R0 = endereço base do port desejado
; R1 = máscara de bits a serem acessados
; R2 = bits lidos
GPIO_read:
        LDR R2, [R0, R1, LSL #2] ; lê bits com máscara de acesso
        BX LR

; SW_delay: atraso de tempo por software
; R0 = valor do atraso
; Destrói: R0
SW_delay:
        CBZ R0, out_delay
        SUB R0, R0, #1
        B SW_delay        
out_delay:
        BX LR

; LED_write: escreve um valor binário nos LEDs D1 a D4 do kit
; R0 = valor a ser escrito nos LEDs (bit 3 a bit 0)
; Destrói: R1, R2, R3 e R4
LED_write:
        AND R3, R0, #0010b
        LSR R3, R3, #1
        AND R4, R0, #0001b
        ORR R3, R3, R4, LSL #1 ; LEDs D1 e D2
        LDR R1, =GPIO_PORTN_BASE
        MOV R2, #000000011b ; máscara PN1|PN0
        STR R3, [R1, R2, LSL #2]

        AND R3, R0, #1000b
        LSR R3, R3, #3
        AND R4, R0, #0100b
        ORR R3, R3, R4, LSL #2 ; LEDs D3 e D4
        LDR R1, =GPIO_PORTF_BASE
        MOV R2, #00010001b ; máscara PF4|PF0
        STR R3, [R1, R2, LSL #2]
        
        BX LR

; Button_read: lê o estado dos botões SW1 e SW2 do kit
; R0 = valor lido dos botões (bit 1 e bit 0)
; Destrói: R1, R2, R3 e R4
Button_read:
        LDR R1, =GPIO_PORTJ_BASE
        MOV R2, #00000011b ; máscara PJ1|PJ0
        LDR R0, [R1, R2, LSL #2]
        
dbc:    MOV R3, #50 ; constante de debounce
again:  CBZ R3, last
        LDR R4, [R1, R2, LSL #2]
        CMP R0, R4
        MOV R0, R4
        ITE EQ
          SUBEQ R3, R3, #1
          BNE dbc
        B again
last:
        BX LR

; Button_int_conf: configura interrupções do botão SW1 do kit
; Destrói: R0, R1 e R2
Button_int_conf:
        MOV R2, #00000001b ; bit do PJ0
        LDR R1, =GPIO_PORTJ_BASE
        
        LDR R0, [R1, #GPIO_IM]
        BIC R0, R0, R2 ; desabilita interrupções
        STR R0, [R1, #GPIO_IM]
        
        LDR R0, [R1, #GPIO_IS]
        BIC R0, R0, R2 ; interrupção por transição
        STR R0, [R1, #GPIO_IS]
        
        LDR R0, [R1, #GPIO_IBE]
        BIC R0, R0, R2 ; uma transição apenas
        STR R0, [R1, #GPIO_IBE]
        
        LDR R0, [R1, #GPIO_IEV]
        BIC R0, R0, R2 ; transição de descida
        STR R0, [R1, #GPIO_IEV]
        
        LDR R0, [R1, #GPIO_ICR]
        ORR R0, R0, R2 ; limpeza de pendências
        STR R0, [R1, #GPIO_ICR]
        
        LDR R0, [R1, #GPIO_IM]
        ORR R0, R0, R2 ; habilita interrupções no port GPIO J
        STR R0, [R1, #GPIO_IM]

        MOV R2, #0xE0000000 ; prioridade mais baixa para a IRQ51
        LDR R1, =NVIC_BASE
        
        LDR R0, [R1, #NVIC_PRI12]
        ORR R0, R0, R2 ; define prioridade da IRQ51 no NVIC
        STR R0, [R1, #NVIC_PRI12]

        MOV R2, #10000000000000000000b ; bit 19 = IRQ51
        MOV R0, R2 ; limpa pendências da IRQ51 no NVIC
        STR R0, [R1, #NVIC_UNPEND1]

        LDR R0, [R1, #NVIC_EN1]
        ORR R0, R0, R2 ; habilita IRQ51 no NVIC
        STR R0, [R1, #NVIC_EN1]
        
        BX LR

; Button1_int_enable: habilita interrupções do botão SW1 do kit
; Destrói: R0, R1 e R2
Button1_int_enable:
        MOV R2, #00000001b ; bit do PJ0
        LDR R1, =GPIO_PORTJ_BASE
        
        LDR R0, [R1, #GPIO_IM]
        ORR R0, R0, R2 ; habilita interrupções
        STR R0, [R1, #GPIO_IM]

        BX LR

; Button1_int_disable: desabilita interrupções do botão SW1 do kit
; Destrói: R0, R1 e R2
Button1_int_disable:
        MOV R2, #00000001b ; bit do PJ0
        LDR R1, =GPIO_PORTJ_BASE
        
        LDR R0, [R1, #GPIO_IM]
        BIC R0, R0, R2 ; desabilita interrupções
        STR R0, [R1, #GPIO_IM]

        BX LR

; Button1_int_clear: limpa pendência de interrupções do botão SW1 do kit
; Destrói: R0 e R1
Button1_int_clear:
        MOV R0, #00000001b ; limpa o bit 0
        LDR R1, =GPIO_PORTJ_BASE
        STR R0, [R1, #GPIO_ICR]

        BX LR

        END

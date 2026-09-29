# AI Trading Bot — MetaTrader 4 + AI

Repositorio central para desarrollar, versionar, probar y operar un **AI Trading Bot para MetaTrader 4 (MT4)**.

El objetivo es separar claramente:

- **GitHub** → código, versiones, configuraciones, estrategias, pruebas y documentación.
- **MetaTrader 4** → conexión con el broker, datos de mercado, ejecución del Expert Advisor (EA), órdenes y gestión de posiciones.
- **AI Engine** → análisis de mercado, diagnóstico, selección de señales y evaluación estadística.
- **Bridge/API** → comunicación segura entre MT4 y el motor de IA.

> **Importante:** GitHub por sí solo no ejecuta un EA de MT4 ni mantiene una terminal MT4 conectada al mercado. Para operar en tiempo real, MT4 debe estar ejecutándose en un Windows/PC/VPS y el EA debe comunicarse con el motor externo.

## Arquitectura objetivo

```
                         GITHUB
                           │
                 código / versiones / CI
                           │
                           ▼
                  AI TRADING BOT REPO
                           │
             ┌─────────────┴─────────────┐
             │                           │
             ▼                           ▼
       MQL4 / EA                  AI / Analytics
       estrategias               señales / modelos
       gestión riesgo            diagnóstico / scoring
             │                           │
             └─────────────┬─────────────┘
                           │
                      BRIDGE / API
                           │
                           ▼
                    METATRADER 4
                           │
                    Broker / Mercado
                           │
                           ▼
                 precios / órdenes / fills
```

## ¿Se puede conectar GitHub con MT4?

**Sí, pero indirectamente.**

MT4 no debe depender directamente de GitHub para cada operación.

El flujo recomendado es:

1. El código MQL4 se mantiene en GitHub.
2. El EA se compila en MetaEditor.
3. El EA se instala en la terminal MT4.
4. MT4 recibe precios y ejecuta las órdenes.
5. El EA envía datos seleccionados a un servidor/API de IA.
6. El motor de IA devuelve una decisión estructurada.
7. El EA aplica filtros locales de riesgo.
8. Solo después de pasar los controles, MT4 puede ejecutar la orden.
9. El resultado de la operación vuelve al sistema para análisis.

MQL4 dispone de comunicación HTTP mediante `WebRequest()`, siempre que el servidor utilizado esté autorizado en las opciones de MT4.

## Modelo de IA

La IA no debe tener acceso irrestricto a la cuenta.

El diseño será:

```
MARKET DATA
    ↓
FEATURES
    ↓
AI ANALYSIS
    ↓
SIGNAL
    ↓
RISK GATE
    ↓
MT4 EXECUTION
```

Una señal puede tener una estructura como:

```json
{
  "symbol": "EURUSD",
  "timeframe": "H1",
  "action": "BUY",
  "confidence": 0.72,
  "entry": 1.16500,
  "stop_loss": 1.16200,
  "take_profit": 1.17100,
  "strategy": "trend",
  "reason": "EMA alignment + ADX + RSI + momentum",
  "risk_allowed": true
}
```

La IA **propone** la operación; el **Risk Gate local del EA** decide si puede ejecutarse.

## Funciones previstas

### 1. Market Analysis

- tendencia
- volatilidad
- momentum
- ADX
- RSI
- EMA
- ATR
- estructura de mercado
- soportes y resistencias
- Fibonacci
- régimen de mercado
- spread
- horario
- contexto de timeframe superior

### 2. AI Decision Engine

La IA podrá:

- analizar las características del mercado
- comparar señales
- detectar condiciones débiles
- clasificar el régimen
- explicar la señal
- registrar el resultado
- comparar estrategias
- detectar degradación del rendimiento
- producir recomendaciones de parámetros para pruebas futuras

### 3. Risk Gate

El EA debe conservar el control final sobre:

- riesgo por operación
- lote máximo
- número máximo de posiciones
- spread máximo
- SL obligatorio
- TP
- drawdown máximo
- pérdida diaria máxima
- horario permitido
- cooldown
- bloqueo después de errores
- bloqueo si la respuesta de IA no es válida

### 4. MT4 Execution

El EA será responsable de:

- `OrderSend`
- modificación de órdenes
- cierre de posiciones
- trailing stop
- break-even
- control de errores
- registro de fills
- sincronización de posiciones
- métricas MAE/MFE
- exportación de datos

## Modos de funcionamiento

### BACKTEST

```
Historical Data
      ↓
MT4 Strategy Tester
      ↓
EA
      ↓
Diagnostics
      ↓
CSV / Reports
```

### DEMO

```
Live Market
     ↓
MT4 Demo
     ↓
EA
     ↓
AI Engine
     ↓
Risk Gate
     ↓
Demo Order
```

### LIVE

Solo después de validar suficientemente el sistema:

```
Live Market
     ↓
MT4
     ↓
EA
     ↓
AI Engine
     ↓
Risk Gate
     ↓
Broker
```

## GitHub Actions

GitHub Actions se utilizará principalmente para:

- validar código
- ejecutar tests
- revisar cambios
- construir artefactos
- validar configuraciones
- generar documentación
- empaquetar versiones del EA

No se utilizará GitHub Actions como sustituto de una terminal MT4 permanente para trading en vivo.

Para ejecución continua, el componente que necesita estar conectado al mercado debe permanecer en Windows/VPS con MT4.

## Estructura prevista

```
AI_Trading_Bot/
│
├── README.md
│
├── mt4/
│   ├── experts/
│   │   ├── AI_Trading_Bot.mq4
│   │   └── AI_Trading_Bot_Live.mq4
│   │
│   ├── include/
│   │   ├── AI_Signal.mqh
│   │   ├── Risk_Gate.mqh
│   │   ├── Market_Regime.mqh
│   │   ├── Execution.mqh
│   │   └── Diagnostics.mqh
│   │
│   └── indicators/
│
├── ai/
│   ├── engine/
│   ├── features/
│   ├── models/
│   ├── evaluation/
│   └── prompts/
│
├── bridge/
│   ├── api/
│   ├── schemas/
│   └── adapters/
│
├── strategies/
│   ├── trend/
│   ├── range/
│   ├── fibonacci/
│   ├── momentum/
│   └── grid/
│
├── backtests/
│   ├── reports/
│   ├── csv/
│   └── configurations/
│
├── tests/
│
├── docs/
│
└── .github/
    └── workflows/
```

## Principio de seguridad

La IA nunca debe poder saltarse el Risk Gate.

Si la IA responde:

- formato inválido
- símbolo incorrecto
- lote inválido
- SL ausente
- TP ausente
- confianza insuficiente
- spread excesivo
- drawdown bloqueado
- fuera de horario
- riesgo superior al límite

la operación debe ser **rechazada por MT4**.

## Desarrollo inicial

El primer objetivo será construir el núcleo alrededor de:

1. **AI_Trading_Bot_v1.33 Entry Diagnostics**
2. corrección y evolución controlada hacia v1.34+
3. Market Regime
4. Signal Engine
5. Risk Gate
6. MT4 ↔ AI Bridge
7. Backtest diagnostics
8. Demo execution
9. posteriormente estrategias como Grid Bot

## Estado

**Repositorio inicializado para el desarrollo del AI Trading Bot para MT4.**

La prioridad es construir primero una arquitectura verificable y medible antes de permitir ejecución real.

## Licencia

Pendiente de definir.

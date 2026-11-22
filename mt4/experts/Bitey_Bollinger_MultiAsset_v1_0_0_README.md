# Bitey Bollinger MultiAsset v1.0.0

## Estado

Primera versión experimental. Archivo nuevo e independiente; no reemplaza Infinity Impulse ni Bitey Scalper.

- EA: `mt4/experts/Bitey_Bollinger_MultiAsset_v1_0_0.mq4`
- Rama: `experimental/bitey-bollinger-multiasset-v1-0-0`
- Estrategia de señales: exclusivamente Bollinger Bands.
- Modos: rebote (mean reversion) y ruptura (breakout).
- Conflicto de señales opuestas en la misma vela: abstención.
- Noticias: modo sombra para SCOUT; add-ons LEVERAGED bloqueados si coincide una ventana de noticias.
- Add-ons financiados: implementados como opción, desactivados por defecto.
- SL/TP: SL y TP iniciales escalados con ATR; break-even, trailing y protección de beneficio previa a noticias. ATR no genera señales.

## Reglas de señal

### Rebote
- BUY: la vela cerrada toca/atraviesa la banda inferior y cierra de nuevo por encima de ella. Si `InpRequireCandleDirection=true`, exige vela alcista.
- SELL: la vela cerrada toca/atraviesa la banda superior y cierra de nuevo por debajo. Si está activada la confirmación de dirección, exige vela bajista.

### Ruptura
- BUY: cierre de la última vela completa por encima de la banda superior, con el cierre anterior en/por debajo de su banda superior.
- SELL: cierre de la última vela completa por debajo de la banda inferior, con el cierre anterior en/por encima de su banda inferior.

No se usan EMA, RSI, MACD, ADX ni otros indicadores para decidir entradas. ATR solo dimensiona SL/TP y trailing.

## Escáner multi-activo

- Por defecto escanea los símbolos de Market Watch.
- Para escanear el universo del broker, configura `InpScanMarketWatch=false`.
- También se puede proporcionar una lista explícita en `InpSymbolsCSV`.
- Cada símbolo requiere histórico mínimo, bid/ask válidos, cotización reciente y permiso de trading del terminal y del broker.
- Cripto se considera calendario esperado 24/7, no disponibilidad garantizada. Si no hay tick reciente o el broker deshabilita el símbolo, no opera.
- No se fuerza ninguna entrada para llenar cupos.

## Riesgo y apalancamiento selectivo

- Riesgo por operación por defecto: 0,50% del balance.
- Riesgo agregado máximo por defecto: 2,50% del balance.
- Máximo 5 posiciones abiertas del EA y 1 posición por símbolo por defecto.
- El lote se redondea hacia abajo. Si el lote mínimo del broker supera el presupuesto monetario, se rechaza la entrada.
- No hay martingala ni incremento de riesgo para recuperar pérdidas.
- El add-on opcional requiere beneficio ya protegido por el SL del padre y financia su riesgo con una fracción de ese beneficio protegido. Sigue sujeto al techo agregado absoluto. Está desactivado por defecto (`InpEnableFundedAddOns=false`).
- El EA no puede cambiar el apalancamiento contractual de la cuenta o del broker; “apalancamiento selectivo” aquí significa únicamente add-ons financiados bajo esas restricciones.

## Selector de noticias

El lector conserva el contrato de archivo de Bitey Scalper v1.5.62. El modo sombra para entradas SCOUT es obligatorio en esta versión: el EA no permite desactivarlo.

Ubicación predeterminada: carpeta común de archivos de MetaTrader (`FILE_COMMON`), con nombre `bitey_news_guard.csv`. Se puede cambiar con `InpNewsUseCommonFolder=false` para usar la carpeta local `MQL4/Files`.

Formato:

```text
#updated_epoch_utc=1795348800
CCY,USD,1795349000,1795350800,BLOCK,US high impact event,1795350000
SYM,BTCUSD,1795349000,1795350800,BLOCK,Symbol-specific event,1795350000
ALL,*,1795349000,1795350800,BLOCK,Global event,1795350000
```

Campos: `scope,key,fromEpochUTC,untilEpochUTC,action,reason,eventEpochUTC`.

- `scope`: `CCY`, `SYM` o `ALL`.
- `action`: solo se leen filas `BLOCK`.
- La cabecera `updated_epoch_utc` debe ser reciente; la antigüedad máxima predeterminada es 30 minutos.
- Si falta el archivo, no tiene cabecera válida o está vencido, el lector registra el estado y falla abierto, siguiendo el comportamiento heredado.
- SCOUT: registra `NEWS_GUARD_SHADOW_WOULD_BLOCK`, pero permite que continúe la evaluación de la entrada.
- LEVERAGED: no permite abrir un add-on cuando coincide una fila BLOCK.
- Protección de posición: si ya existe beneficio neto suficiente, puede subir el SL para intentar asegurar el porcentaje configurado. Nunca amplía el SL.
- Este repositorio no incluye todavía el productor externo `bitey_news_agent.py`; debe generarse y mantenerse el CSV para tener datos de noticias reales. Sin productor, no existe cobertura real de calendario.

## Instalación y validación pendiente

1. Copiar el MQ4 a `MQL4/Experts`.
2. Abrirlo en MetaEditor y compilar.
3. Ejecutar primero en cuenta demo y Strategy Tester, con el mismo broker y especificaciones de contrato.
4. Revisar logs `SCANNER_UNIVERSE`, `SCAN_SKIP`, `SIGNAL_ABSTAIN`, `SCOUT_OPEN`, `NEWS_GUARD_*` y `PROTECTIVE_SL_UPDATE`.
5. No activar add-ons financiados hasta revisar resultados de demo y comprobar el cálculo de tick value/tick size del broker.

**Verificación:** el archivo fue creado y revisado estáticamente. No se ha ejecutado MetaEditor, no hay confirmación de compilación, backtest, forward test ni operación real. No debe instalarse en una cuenta real antes de esas pruebas.

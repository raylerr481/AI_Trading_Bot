#ifndef __TRADING_METRICS_MQH__
#define __TRADING_METRICS_MQH__

struct TradingMetrics
{
   double balance;
   double equity;
   double peak_equity;
   double drawdown_money;
   double drawdown_pct;
   double floating_pl;
   int open_trades;
   int closed_trades;
   int wins;
   int losses;
   double win_rate;
   double profit_factor;
   double expectancy;
   double avg_win;
   double avg_loss;
   int consecutive_wins;
   int consecutive_losses;
   double trades_per_hour;
   double spread_points;
   double atr_points;
   double adx;
   double hurst;
   int last_regime;
   string best_strategy;
   double best_strategy_score;
};

void MetricsInit(TradingMetrics &m)
{
   m.balance=AccountBalance();
   m.equity=AccountEquity();
   m.peak_equity=m.equity;
   m.drawdown_money=0.0;
   m.drawdown_pct=0.0;
   m.floating_pl=AccountEquity()-AccountBalance();
   m.open_trades=0;
   m.closed_trades=0;
   m.wins=0;
   m.losses=0;
   m.win_rate=0.0;
   m.profit_factor=0.0;
   m.expectancy=0.0;
   m.avg_win=0.0;
   m.avg_loss=0.0;
   m.consecutive_wins=0;
   m.consecutive_losses=0;
   m.trades_per_hour=0.0;
   m.spread_points=0.0;
   m.atr_points=0.0;
   m.adx=0.0;
   m.hurst=0.5;
   m.last_regime=0;
   m.best_strategy="NONE";
   m.best_strategy_score=0.0;
}

void MetricsRefresh(TradingMetrics &m,string symbol,int timeframe)
{
   m.balance=AccountBalance();
   m.equity=AccountEquity();
   if(m.equity>m.peak_equity) m.peak_equity=m.equity;
   m.drawdown_money=MathMax(0.0,m.peak_equity-m.equity);
   m.drawdown_pct=(m.peak_equity>0.0 ? 100.0*m.drawdown_money/m.peak_equity : 0.0);
   m.floating_pl=m.equity-m.balance;
   m.open_trades=0;

   for(int i=OrdersTotal()-1;i>=0;i--)
      if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES) && OrderSymbol()==symbol)
         if(OrderType()==OP_BUY || OrderType()==OP_SELL) m.open_trades++;

   double gross_profit=0.0, gross_loss=0.0, sum=0.0, win_sum=0.0, loss_sum=0.0;
   int trades=0,wins=0,losses=0,current_w=0,current_l=0;
   datetime first=0,last=0;

   for(int j=OrdersHistoryTotal()-1;j>=0;j--)
   {
      if(!OrderSelect(j,SELECT_BY_POS,MODE_HISTORY)) continue;
      if(OrderSymbol()!=symbol) continue;
      if(OrderType()!=OP_BUY && OrderType()!=OP_SELL) continue;

      double p=OrderProfit()+OrderSwap()+OrderCommission();
      if(last==0 || OrderCloseTime()>last) last=OrderCloseTime();
      if(first==0 || OrderCloseTime()<first) first=OrderCloseTime();

      trades++;
      sum+=p;
      if(p>0.0)
      {
         wins++; win_sum+=p; gross_profit+=p;
         current_w++; current_l=0;
      }
      else if(p<0.0)
      {
         losses++; loss_sum+=p; gross_loss+=-p;
         current_l++; current_w=0;
      }
      if(current_w>m.consecutive_wins) m.consecutive_wins=current_w;
      if(current_l>m.consecutive_losses) m.consecutive_losses=current_l;
   }

   m.closed_trades=trades;
   m.wins=wins;
   m.losses=losses;
   m.win_rate=(trades>0 ? 100.0*wins/trades : 0.0);
   m.profit_factor=(gross_loss>0.0 ? gross_profit/gross_loss : (gross_profit>0.0 ? 999.0 : 0.0));
   m.expectancy=(trades>0 ? sum/trades : 0.0);
   m.avg_win=(wins>0 ? win_sum/wins : 0.0);
   m.avg_loss=(losses>0 ? loss_sum/losses : 0.0);

   double hours=(last>first ? (last-first)/3600.0 : 0.0);
   m.trades_per_hour=(hours>0.0 ? trades/hours : 0.0);
   double point=MarketInfo(symbol,MODE_POINT);
   m.spread_points=(point>0.0 ? (MarketInfo(symbol,MODE_ASK)-MarketInfo(symbol,MODE_BID))/point : 0.0);
   m.atr_points=(point>0.0 ? iATR(symbol,timeframe,14,1)/point : 0.0);
   m.adx=iADX(symbol,timeframe,14,PRICE_CLOSE,MODE_MAIN,1);
}

#endif

#ifndef __STRATEGY_SPECTRUM_MQH__
#define __STRATEGY_SPECTRUM_MQH__

#define STRATEGY_COUNT 8

string StrategyName(int id)
{
   if(id==0) return "TREND_FOLLOWING";
   if(id==1) return "MEAN_REVERSION";
   if(id==2) return "MOMENTUM";
   if(id==3) return "VOLATILITY_BREAKOUT";
   if(id==4) return "SESSION_BIAS";
   if(id==5) return "DIVERGENCE";
   if(id==6) return "STRICT_RANGE";
   if(id==7) return "FRACTAL_HTF";
   return "UNKNOWN";
}

struct StrategyAudit
{
   int trades;
   int wins;
   int losses;
   double net;
   double gross_profit;
   double gross_loss;
   double win_rate;
   double profit_factor;
   double expectancy;
   double avg_win;
   double avg_loss;
   double max_drawdown;
   double payoff;
   int max_consecutive_losses;
   double score;
};

void ResetAudit(StrategyAudit &a)
{
   a.trades=0; a.wins=0; a.losses=0; a.net=0.0;
   a.gross_profit=0.0; a.gross_loss=0.0; a.win_rate=0.0;
   a.profit_factor=0.0; a.expectancy=0.0; a.avg_win=0.0;
   a.avg_loss=0.0; a.max_drawdown=0.0; a.payoff=0.0;
   a.max_consecutive_losses=0; a.score=0.0;
}

double ATRv(string s,int tf,int shift,int p=14){ return iATR(s,tf,p,shift); }
double ADXv(string s,int tf,int shift,int p=14){ return iADX(s,tf,p,PRICE_CLOSE,MODE_MAIN,shift); }
double RSIv(string s,int tf,int shift,int p=14){ return iRSI(s,tf,p,PRICE_CLOSE,shift); }
double EMAv(string s,int tf,int shift,int p){ return iMA(s,tf,p,0,MODE_EMA,PRICE_CLOSE,shift); }

int StrategySignal(string s,int tf,int shift,int id)
{
   double c=iClose(s,tf,shift), p=iClose(s,tf,shift+1);
   double atr=ATRv(s,tf,shift), adx=ADXv(s,tf,shift), rsi=RSIv(s,tf,shift);
   double fast=EMAv(s,tf,shift,8), slow=EMAv(s,tf,shift,21);
   double macro=EMAv(s,tf,shift,200);
   if(atr<=0.0) return 0;

   if(id==0)
   {
      if(fast>slow && c>macro && adx>=22.0) return 1;
      if(fast<slow && c<macro && adx>=22.0) return -1;
   }
   if(id==1)
   {
      if(rsi<=30.0 && c<fast-0.5*atr) return 1;
      if(rsi>=70.0 && c>fast+0.5*atr) return -1;
   }
   if(id==2)
   {
      if(c>p && c>iClose(s,tf,shift+3) && rsi>=55.0) return 1;
      if(c<p && c<iClose(s,tf,shift+3) && rsi<=45.0) return -1;
   }
   if(id==3)
   {
      double hi=iHigh(s,tf,iHighest(s,tf,MODE_HIGH,20,shift+1));
      double lo=iLow(s,tf,iLowest(s,tf,MODE_LOW,20,shift+1));
      if(c>hi && adx>=20.0) return 1;
      if(c<lo && adx>=20.0) return -1;
   }
   if(id==4)
   {
      int h=TimeHour(iTime(s,tf,shift));
      double sessionOpen=iOpen(s,tf,MathMin(20,Bars(s,tf)-shift-2));
      if(h>=7 && h<=10 && c>sessionOpen) return 1;
      if(h>=7 && h<=10 && c<sessionOpen) return -1;
   }
   if(id==5)
   {
      double rsiPrev=RSIv(s,tf,shift+5);
      double cPrev=iClose(s,tf,shift+5);
      if(c<cPrev && rsi>rsiPrev+5.0 && rsi<45.0) return 1;
      if(c>cPrev && rsi<rsiPrev-5.0 && rsi>55.0) return -1;
   }
   if(id==6)
   {
      double hi=iHigh(s,tf,iHighest(s,tf,MODE_HIGH,30,shift+1));
      double lo=iLow(s,tf,iLowest(s,tf,MODE_LOW,30,shift+1));
      double width=hi-lo;
      if(width<=0.0) return 0;
      double mid=(hi+lo)/2.0;
      if(adx<20.0 && c<lo+0.20*width) return 1;
      if(adx<20.0 && c>hi-0.20*width) return -1;
      if(adx<20.0 && c<mid && rsi<45.0) return 1;
      if(adx<20.0 && c>mid && rsi>55.0) return -1;
   }
   if(id==7)
   {
      double htfFast=iMA(s,PERIOD_H4,8,0,MODE_EMA,PRICE_CLOSE,shift+1);
      double htfSlow=iMA(s,PERIOD_H4,21,0,MODE_EMA,PRICE_CLOSE,shift+1);
      double ph=iHigh(s,tf,shift+2), pc=iHigh(s,tf,shift+3);
      double pl=iLow(s,tf,shift+2), lc=iLow(s,tf,shift+3);
      if(ph>pc && ph>iHigh(s,tf,shift+1) && htfFast>htfSlow) return 1;
      if(pl<lc && pl<iLow(s,tf,shift+1) && htfFast<htfSlow) return -1;
   }
   return 0;
}

void FinalizeAudit(StrategyAudit &a)
{
   a.win_rate=(a.trades>0 ? 100.0*a.wins/a.trades : 0.0);
   a.profit_factor=(a.gross_loss>0.0 ? a.gross_profit/a.gross_loss : (a.gross_profit>0.0 ? 999.0 : 0.0));
   a.expectancy=(a.trades>0 ? a.net/a.trades : 0.0);
   a.avg_win=(a.wins>0 ? a.gross_profit/a.wins : 0.0);
   a.avg_loss=(a.losses>0 ? -a.gross_loss/a.losses : 0.0);
   a.payoff=(a.avg_loss!=0.0 ? a.avg_win/MathAbs(a.avg_loss) : 0.0);

   double expectancy_component=MathMax(-2.0,MathMin(2.0,a.expectancy));
   double pf_component=MathMax(0.0,MathMin(3.0,a.profit_factor));
   double dd_penalty=MathMax(0.0,MathMin(3.0,a.max_drawdown));
   double win_component=MathMax(0.0,MathMin(1.0,a.win_rate/100.0));
   a.score=expectancy_component+pf_component+win_component-dd_penalty;
}

bool AuditStrategy(string s,int tf,int id,int bars_to_test,int horizon,
                   double sl_mult,double tp_mult,StrategyAudit &a)
{
   ResetAudit(a);
   int max_shift=MathMin(bars_to_test,Bars(s,tf)-horizon-25);
   if(max_shift<20) return false;

   double equity=0.0, peak=0.0;
   int losing_streak=0;

   for(int shift=max_shift;shift>=horizon+2;shift--)
   {
      int dir=StrategySignal(s,tf,shift,id);
      if(dir==0) continue;

      double entry=iClose(s,tf,shift);
      double atr=ATRv(s,tf,shift);
      if(atr<=0.0) continue;

      double slDist=sl_mult*atr, tpDist=tp_mult*atr;
      bool resolved=false, win=false;
      double result=0.0;

      for(int f=shift-1;f>=shift-horizon && f>=1;f--)
      {
         double hi=iHigh(s,tf,f), lo=iLow(s,tf,f);
         if(dir>0)
         {
            if(lo<=entry-slDist) { resolved=true; win=false; result=-slDist; break; }
            if(hi>=entry+tpDist) { resolved=true; win=true; result=tpDist; break; }
         }
         else
         {
            if(hi>=entry+slDist) { resolved=true; win=false; result=-slDist; break; }
            if(lo<=entry-tpDist) { resolved=true; win=true; result=tpDist; break; }
         }
      }

      if(!resolved) continue;

      a.trades++;
      a.net+=result;
      equity+=result;
      if(equity>peak) peak=equity;
      a.max_drawdown=MathMax(a.max_drawdown,peak-equity);

      if(win)
      {
         a.wins++; a.gross_profit+=result; losing_streak=0;
      }
      else
      {
         a.losses++; a.gross_loss+=MathAbs(result); losing_streak++;
         a.max_consecutive_losses=MathMax(a.max_consecutive_losses,losing_streak);
      }
   }

   FinalizeAudit(a);
   return (a.trades>=10);
}

int SelectBestStrategy(StrategyAudit &audits[],int &bestId)
{
   bestId=-1;
   double best=-999999.0;
   for(int i=0;i<STRATEGY_COUNT;i++)
   {
      if(audits[i].trades<10) continue;
      if(audits[i].score>best) { best=audits[i].score; bestId=i; }
   }
   return bestId;
}

#endif

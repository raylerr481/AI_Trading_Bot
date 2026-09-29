#ifndef __MARKET_REGIME_MQH__
#define __MARKET_REGIME_MQH__

enum MarketRegime
{
   REGIME_UNKNOWN=0,
   REGIME_UPTREND=1,
   REGIME_DOWNTREND=2,
   REGIME_RANGE=3,
   REGIME_HIGH_VOL=4
};

string RegimeName(MarketRegime r)
{
   if(r==REGIME_UPTREND) return "UPTREND";
   if(r==REGIME_DOWNTREND) return "DOWNTREND";
   if(r==REGIME_RANGE) return "RANGE";
   if(r==REGIME_HIGH_VOL) return "HIGH_VOL";
   return "UNKNOWN";
}

MarketRegime DetectMarketRegime(double atr_points,double adx,double fast,double slow,
                                double macro,double macro_prev,double min_atr_points,
                                double adx_min)
{
   if(atr_points < min_atr_points) return REGIME_RANGE;
   if(adx >= 25.0 && fast > slow && macro > macro_prev) return REGIME_UPTREND;
   if(adx >= 25.0 && fast < slow && macro < macro_prev) return REGIME_DOWNTREND;
   if(adx >= 40.0) return REGIME_HIGH_VOL;
   if(adx < adx_min) return REGIME_RANGE;
   return REGIME_UNKNOWN;
}

double EstimateHurst(string symbol,int timeframe,int shift,int length)
{
   if(length < 16) return 0.5;
   double mean=0.0;
   int n=0;
   for(int i=shift;i<shift+length && i<Bars(symbol,timeframe);i++)
   {
      mean += iClose(symbol,timeframe,i);
      n++;
   }
   if(n<16) return 0.5;
   mean/=n;

   double cumulative=0.0, range=0.0, variance=0.0;
   for(int j=0;j<n;j++)
   {
      double x=iClose(symbol,timeframe,shift+j)-mean;
      cumulative+=x;
      if(cumulative>range) range=cumulative;
      if(cumulative<0.0 && -cumulative>range) range=-cumulative;
      variance+=x*x;
   }
   double sd=MathSqrt(variance/MathMax(1,n-1));
   if(sd<=0.0 || range<=0.0) return 0.5;

   double h=MathLog(range/sd)/MathLog(n);
   return MathMax(0.0,MathMin(1.0,h));
}

#endif

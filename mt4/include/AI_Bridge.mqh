#ifndef __AI_BRIDGE_MQH__
#define __AI_BRIDGE_MQH__

struct AITradingSignal
{
   string action;
   double confidence;
   bool risk_allowed;
   string strategy;
   string reason;
};

string AIJsonString(string body,string key,string fallback="")
{
   string needle="\""+key+"\":\"";
   int p=StringFind(body,needle);
   if(p<0) return fallback;
   p+=StringLen(needle);
   int e=StringFind(body,"\"",p);
   if(e<0) return fallback;
   return StringSubstr(body,p,e-p);
}

double AIJsonNumber(string body,string key,double fallback=0.0)
{
   string needle="\""+key+"\":";
   int p=StringFind(body,needle);
   if(p<0) return fallback;
   p+=StringLen(needle);
   int e=StringFind(body,",",p);
   if(e<0) e=StringFind(body,"}",p);
   if(e<0) return fallback;
   return StrToDouble(StringSubstr(body,p,e-p));
}

bool AIJsonBool(string body,string key,bool fallback=false)
{
   string needle="\""+key+"\":";
   int p=StringFind(body,needle);
   if(p<0) return fallback;
   p+=StringLen(needle);
   string value=StringSubstr(body,p,5);
   if(StringFind(value,"true")>=0) return true;
   if(StringFind(value,"false")>=0) return false;
   return fallback;
}

bool AIAnalyzeSnapshot(
   string endpoint,
   string token,
   string symbol,
   string timeframe,
   double bid,
   double ask,
   double spread_points,
   double atr_points,
   double adx,
   double rsi,
   double ema_fast,
   double ema_slow,
   double ema_macro,
   double close_price,
   double previous_close,
   string regime,
   int timeout_ms,
   AITradingSignal &signal
)
{
   signal.action="HOLD";
   signal.confidence=0.0;
   signal.risk_allowed=false;
   signal.strategy="none";
   signal.reason="No AI response.";

   string json=StringFormat(
      "{\"symbol\":\"%s\",\"timeframe\":\"%s\","
      "\"bid\":%.10f,\"ask\":%.10f,\"spread_points\":%.2f,"
      "\"atr_points\":%.2f,\"adx\":%.2f,\"rsi\":%.2f,"
      "\"ema_fast\":%.10f,\"ema_slow\":%.10f,\"ema_macro\":%.10f,"
      "\"close\":%.10f,\"previous_close\":%.10f,\"regime\":\"%s\"}",
      symbol,timeframe,bid,ask,spread_points,atr_points,adx,rsi,
      ema_fast,ema_slow,ema_macro,close_price,previous_close,regime
   );

   char post[];
   StringToCharArray(json,post,0,WHOLE_ARRAY,CP_UTF8);

   string headers="Content-Type: application/json\r\n";
   if(StringLen(token)>0)
      headers+="X-Trading-Module-Token: "+token+"\r\n";

   char result[];
   string result_headers="";
   ResetLastError();
   int status=WebRequest("POST",endpoint,headers,timeout_ms,post,result,result_headers);
   if(status<200 || status>=300)
      return false;

   string body=CharArrayToString(result,0,-1,CP_UTF8);
   string action=AIJsonString(body,"action","HOLD");
   StringToUpper(action);
   if(action!="BUY" && action!="SELL" && action!="HOLD") action="HOLD";

   signal.action=action;
   signal.confidence=MathMax(0.0,MathMin(1.0,AIJsonNumber(body,"confidence",0.0)));
   signal.risk_allowed=AIJsonBool(body,"risk_allowed",false);
   signal.strategy=AIJsonString(body,"strategy","advisory");
   signal.reason=AIJsonString(body,"reason","No reason supplied.");

   return true;
}

#endif

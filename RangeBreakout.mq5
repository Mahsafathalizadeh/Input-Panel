//the strategy is about trading range breakout

//include
#include <Trade/Trade.mqh>
#include <GraphicalPanel.mqh>

//inputs
input group "=== General Inputs ==="
input long InpMagicNumber = 12345;
input double InpLots = 1;
input int InpStopLoss = 100;      //sl in % of the range
input int InpTakeProfit = 100;    //tp in % of the range

input group "=== Range Inputs ==="
input int InpRangeStart = 600;     //number of minutes after midnight
input int InpRangeDuration = 120;
input int InpRangeClose = 1200;    //(-1 = off)
enum BREAKOUT_MODE_ENUM{
    ONE_SIGNAl,    //one breakout per range
    TWO_SIGNAlS   //high and low breakout
};
input BREAKOUT_MODE_ENUM InpBreakoutMode = ONE_SIGNAl;   //breakout mode

input group "=== Dow filter ==="
input bool InpMonday = true;      //range on monday
input bool InpTuesday = true;      
input bool InpWednesday = true;      
input bool InpThursday = true;      
input bool InpFriday = true;      

//Global variables
struct RANGE_STRUCT
{
    datetime start_time;  //start of range
    datetime end_time;    //end of the range
    datetime close_time;  //close time
    double high;          //high of the range
    double low;           //low of the range
    bool f_entry;         //flage if we are inside the range
    bool f_high_breakout;  //flag if a high breakout occured
    bool f_low_breakout;   //flag if a low breakout occured

    RANGE_STRUCT():start_time(0),end_time(0),close_time(0),high(0),low(DBL_MAX),f_entry(false),f_high_breakout(false),f_low_breakout(false){};
};
RANGE_STRUCT range;
MqlTick prevTick, lastTick;
CTrade trade;
CGraphicalPanel panel;


int OnInit()
{
    //check input
    if (!CheckInputs())
    {
        return INIT_PARAMETERS_INCORRECT;
    }

    //set magicnumber
    trade.SetExpertMagicNumber(InpMagicNumber);
    
    //calculate new range if inputs changed
    if (_UninitReason==REASON_PARAMETERS && CountOpenPositions()==0)
    {
        //add later:no position open
        CalculateRange();
    }
    
    //draw objects
    DrawObjects();

    //create panel
    if(!panel.OnInit()){return INIT_FAILED; };

    return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
    //delete obj
    //ObjectsDeleteAll(NULL,"range");
    
    //destroy panel
    panel.Destroy(reason);
}

void OnTick()
{
   //get current tick
   prevTick = lastTick;
   SymbolInfoTick(_Symbol,lastTick);
    
    //range calculation
    if (lastTick.time >= range.start_time && lastTick.time < range.end_time)
    {
        //set flag
        range.f_entry=true;
        //new high
        if (lastTick.ask >= range.high)
        {
            range.high = lastTick.ask;
            DrawObjects();
        }
        //new low
        if (lastTick.bid <= range.low)
        {
            range.low = lastTick.bid;
            DrawObjects();
        }
    }

    //close positions
    if (InpRangeClose>=0 && lastTick.time >= range.close_time)
    {
        if (!ClosePositions())
        {
            return;
        }
        
    }
    

    
   //calculate new range if..
   if ((InpRangeClose>=0 && lastTick.time>range.close_time)                       //close time reached
   || (range.f_high_breakout && range.f_low_breakout)                             //both breakout flags are true
   || (range.end_time==0)                                                        //range not calculated yet
   || (range.end_time!=0 && lastTick.time>range.end_time && !range.f_entry      //there was a range calculated but no tick inside
   && CountOpenPositions()==0)
   )
   {
    CalculateRange();
   }

    //check for breakouts
    CheckBreakouts();
}

//======================================Chart Event Handler============================

void OnChartEvent(const int id,const long &lparam, const double &dparam, const string &sparam)
{
    panel.PanelChartEvent(id,lparam,dparam,sparam);

}

//check user inputs
bool CheckInputs()
{
    if (InpMagicNumber <= 0){Alert("magic number is <=0");return false;}
    if (InpLots <= 0 || InpLots>1){Alert("Lots <=0 or >1");return false;}

    if (InpRangeStart < 0 || InpRangeStart>=86400){Alert("range star <0 or >=1440");return false;}
    if (InpRangeDuration <=0 || InpRangeDuration >=86400){Alert("range duration <=0 or >=1440");return false;}

    if ( InpRangeClose>=1440 || (InpRangeStart+InpRangeDuration)%1440 == InpRangeClose){Alert("close time >=1440 or end time ==close time");return false;}
    if (InpStopLoss<0 || InpStopLoss > 1000){Alert("stop loss is <0 or >1000");return false;}

    if (InpTakeProfit<0 || InpTakeProfit > 1000){Alert("take profit is <0 or >1000");return false;}
    if (InpRangeClose<0 && InpStopLoss==0){Alert("close time and sl are off.");return false;}
    
    if (InpMonday+InpTuesday+InpWednesday+InpThursday+InpFriday==0){Alert("range is prohibited on all days of the week");return false;}
    return true;
}

//calculate a new range
void CalculateRange()
{
    //reset range variables
    range.start_time = 0;
    range.end_time = 0;
    range.close_time = 0;
    range.high = 0.0;
    range.low = DBL_MAX;
    range.f_entry = false;
    range.f_high_breakout = false;
    range.f_low_breakout = false;

    //calculate range start time
    int time_cycle = 86400;  //number of seconds in 1 day
    range.start_time = (lastTick.time - (lastTick.time % time_cycle)) + InpRangeStart*60;   //(lastTick.time - (lastTick.time % time_cycle))  => gives us start of each day

    for (int i = 0; i < 8; i++)
    {
        MqlDateTime tmp;
        TimeToStruct(range.start_time,tmp);
        int dow = tmp.day_of_week;
        if (lastTick.time>=range.start_time ||dow==6 ||dow==0 || (dow==1 && !InpMonday)|| (dow==2 && !InpTuesday)|| (dow==3 && !InpWednesday)|| (dow==4 && !InpThursday)|| (dow==5 && !InpFriday))
        {
            range.start_time += time_cycle;
        }        
    }
    
    //calculate the range end time
    range.end_time = range.start_time + InpRangeDuration*60;
    for (int i = 0; i < 2; i++)
    {
        MqlDateTime tmp;
        TimeToStruct(range.end_time,tmp);
        int dow = tmp.day_of_week;
        if (dow==6||dow==0)
        {
            range.end_time += time_cycle;
        }    
    }
    
    //claculate the close time(when we want to close the positions)
    if (InpRangeClose >=0)
    {
        range.close_time = (range.end_time - (range.end_time % time_cycle)) + InpRangeClose*60;   
        for (int i = 0; i < 3; i++)
        {
            MqlDateTime tmp;
            TimeToStruct(range.close_time ,tmp);
            int dow = tmp.day_of_week;
            if (range.close_time<=range.end_time ||dow==6 ||dow==0)
            {
                range.close_time += time_cycle;
            }        
        } 
    }
    
      
    //draw objects
    DrawObjects();

    //update panel
    panel.Update();
}

//count all open positions
int CountOpenPositions()
{
    int counter=0;
    int total = PositionsTotal();
    for (int i = total-1; i>=0 ; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if (ticket<=0){Print("Failed to get position ticket");return -1;}
        
        if (!PositionSelectByTicket(ticket)){Print("Failed to select position by ticket");return -1;}

        ulong magicnumber;
        if (!PositionGetInteger(POSITION_MAGIC,magicnumber)){Print("Failed to get position magicnumber");return -1;}

        if (magicnumber==InpMagicNumber){counter++;}
    }
    return counter;
}

//check for breakouts
void CheckBreakouts()
{
    //check if we are after the range end
    if (lastTick.time >=range.end_time && range.end_time > 0 && range.f_entry)
    {
        //check for high breakout 
        if (!range.f_high_breakout && lastTick.ask >= range.high)
        {
            range.f_high_breakout = true;
            if (InpBreakoutMode==ONE_SIGNAl)
            {
                range.f_low_breakout = true;
            }
            

            //calculate tp & sl
            double sl = InpStopLoss == 0 ? 0 : NormalizeDouble(lastTick.bid - ((range.high-range.low) * InpStopLoss*0.01),_Digits);       //(range.high - range.low) * InpStopLoss * 0.01 calculates the stop-loss distance as a percentage of the range.    //InpStopLoss * 0.01: This multiplies the stop-loss level by 0.01, effectively converting it from a percentage to a decimal. 
            double tp = InpTakeProfit == 0 ? 0 : NormalizeDouble(lastTick.bid + ((range.high-range.low) * InpTakeProfit*0.01),_Digits); 

            //open a buy position
            trade.PositionOpen(_Symbol,ORDER_TYPE_BUY,InpLots,lastTick.ask,sl,tp,"Time range EA");
        }
        //check for low breakout 
        if (!range.f_low_breakout && lastTick.bid <= range.low)
        {
            range.f_low_breakout = true;
            if (InpBreakoutMode==ONE_SIGNAl)
                        {
                            range.f_high_breakout = true;
                        }
             //calculate tp & sl
            double sl = InpStopLoss == 0 ? 0 : NormalizeDouble(lastTick.ask + ((range.high-range.low) * InpStopLoss*0.01),_Digits);     
            double tp = InpTakeProfit == 0 ? 0 : NormalizeDouble(lastTick.ask - ((range.high-range.low) * InpTakeProfit*0.01),_Digits); 

            //open a sell position
            trade.PositionOpen(_Symbol,ORDER_TYPE_SELL,InpLots,lastTick.bid,sl,tp,"Time range EA");
        }
    }
}

//close all open positions
bool ClosePositions()
{
    int total = PositionsTotal();
    for (int i = total-1; i >=0; i--)
    {
        if (total != PositionsTotal())
        {
            total=PositionsTotal();
            i=total;
            continue;
        }
        ulong ticket = PositionGetTicket(i);  //select position
        if (ticket<=0)
        {
            Print("failed to get position ticket");
            return false;
        }
        if (!PositionSelectByTicket(ticket))
        {
            Print("failed to select position by ticket");
            return false;
        }
        long magicnumber;
        if (!PositionGetInteger(POSITION_MAGIC,magicnumber))
        {
            Print("Failed to get position magicnumber");
            return false;
        }
        if (magicnumber == InpMagicNumber)
        {
            trade.PositionClose(ticket);
            if (trade.ResultRetcode() != TRADE_RETCODE_DONE)
            {
                Print("Failed to close position result: "+ (string)trade.ResultRetcode() + ":"+trade.CheckResultRetcodeDescription());
                return false;
            }    
        }
    }
    return true;
}

//draw chart objects
void DrawObjects()
{
    //start
    ObjectDelete(NULL,"range start");
    if (range.start_time>0)
    {
        ObjectCreate(NULL,"range start",OBJ_VLINE,0,range.start_time,0);
        ObjectSetString(NULL,"range start",OBJPROP_TOOLTIP,"start of the range \n"+TimeToString(range.start_time,TIME_DATE|TIME_MINUTES));
        ObjectSetInteger(NULL,"range start",OBJPROP_COLOR,clrWhite);
        ObjectSetInteger(NULL,"range start",OBJPROP_WIDTH,2);
        ObjectSetInteger(NULL,"range start",OBJPROP_BACK,true);
    }
    //end
    ObjectDelete(NULL,"range end");
    if (range.end_time>0)
    {
        ObjectCreate(NULL,"range end",OBJ_VLINE,0,range.end_time,0);
        ObjectSetString(NULL,"range end",OBJPROP_TOOLTIP,"end of the range \n"+TimeToString(range.end_time,TIME_DATE|TIME_MINUTES));
        ObjectSetInteger(NULL,"range end",OBJPROP_COLOR,clrYellow);
        ObjectSetInteger(NULL,"range end",OBJPROP_WIDTH,2);
        ObjectSetInteger(NULL,"range end",OBJPROP_BACK,true);
    }
    //close
    ObjectDelete(NULL,"range close");
    if (range.close_time>0)
    {
        ObjectCreate(NULL,"range close",OBJ_VLINE,0, range.close_time,0);
        ObjectSetString(NULL,"range close",OBJPROP_TOOLTIP,"close of the range \n"+TimeToString(range.close_time,TIME_DATE|TIME_MINUTES));
        ObjectSetInteger(NULL,"range close",OBJPROP_COLOR,clrRed);
        ObjectSetInteger(NULL,"range close",OBJPROP_WIDTH,2);
        ObjectSetInteger(NULL,"range close",OBJPROP_BACK,true);
    }
    //high
    ObjectsDeleteAll(NULL, "range high");

    if (range.high > 0)
    {
        // First "range high" object
        ObjectCreate(NULL, "range high", OBJ_TREND, 0, range.start_time, range.high, range.end_time, range.high);
        ObjectSetString(NULL, "range high", OBJPROP_TOOLTIP, "high of the range \n" + DoubleToString(range.high, _Digits));
        ObjectSetInteger(NULL, "range high", OBJPROP_COLOR, clrRed);
        ObjectSetInteger(NULL, "range high", OBJPROP_WIDTH, 2);
        ObjectSetInteger(NULL, "range high", OBJPROP_BACK, true);

        // Second "range high" object
        ObjectCreate(NULL, "range high 2", OBJ_TREND, 0, range.end_time, range.high,InpRangeClose>=0 ? range.close_time : DBL_MAX, range.high);
        ObjectSetString(NULL, "range high 2", OBJPROP_TOOLTIP, "high of the range \n" + DoubleToString(range.high, _Digits));
        ObjectSetInteger(NULL, "range high 2", OBJPROP_COLOR, clrPink);
        ObjectSetInteger(NULL, "range high 2", OBJPROP_BACK, true);
        ObjectSetInteger(NULL, "range high 2", OBJPROP_STYLE, STYLE_DOT);
    }

    //low
    ObjectsDeleteAll(NULL,"range low");
    if (range.low < DBL_MAX)
    {
        ObjectCreate(NULL,"range low",OBJ_TREND,0, range.start_time, range.low, range.end_time, range.low);
        ObjectSetString(NULL,"range low",OBJPROP_TOOLTIP,"low of the range \n"+DoubleToString(range.low,_Digits));
        ObjectSetInteger(NULL,"range low",OBJPROP_COLOR,clrLightSalmon);
        ObjectSetInteger(NULL,"range low",OBJPROP_WIDTH,2);
        ObjectSetInteger(NULL,"range low",OBJPROP_BACK,true);


        
        ObjectCreate(NULL,"range low 2",OBJ_TREND,0,range.end_time,range.low, InpRangeClose>=0 ? range.close_time : INT_MAX, range.low);
        ObjectSetString(NULL,"range low 2",OBJPROP_TOOLTIP,"low of the range \n"+DoubleToString(range.low,_Digits));
        ObjectSetInteger(NULL,"range low 2",OBJPROP_COLOR,clrLightBlue);
        ObjectSetInteger(NULL,"range low 2",OBJPROP_BACK,true);
        ObjectSetInteger(NULL,"range low 2",OBJPROP_STYLE,STYLE_DOT);
    }

    //refresh chart
    ChartRedraw();
}

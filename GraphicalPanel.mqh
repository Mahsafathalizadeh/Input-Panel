//###<Experts/Advisors/Lesson-03.mq5>

//include 1

#include <Controls/Defines.mqh>
#include <../Experts/Advisors/Lesson-03.mq5>


//Define statements to change default dialoge settings
#undef CONTROLS_FONT_NAME
#undef  CONTROLS_DIALOG_COLOR_CLIENT_BG
#define CONTROLS_FONT_NAME                "Consolas"
#define CONTROLS_DIALOG_COLOR_CLIENT_BG   C'0x20,0x20,0x20'

//include 2
#include <Controls/Dialog.mqh>
#include <Controls/Label.mqh>
#include <Controls/Button.mqh>

//inputs
input group "===Panel Inputs==="
static input int InpPanelWidth     = 260;                  //width in pixel
static input int InpPanelHeight    = 230;                 //hight in pixel
static input int InpPanelFontSize  = 10;                 //font size
static input color InpPanelTextColor = clrWhiteSmoke;   //text color

//-----------------------class CGraphicalPanel-----------------------------
class CGraphicalPanel : public CAppDialog
{
    
    private:
        //private methods
        bool CreatePanel();
        bool CheckInputs();
        void OnClickChangeColor();

        //private variables:
        //buttons
        CButton m_bchangeColor;
        bool m_f_color;


        //labels
        CLabel m_lInput;
        CLabel m_lMagic;
        CLabel m_lLots;
        CLabel m_lStart;
        CLabel m_lDuration;
        CLabel m_lClose;

    public:

        void CGraphicalPanel();
        void ~CGraphicalPanel();
        bool OnInit();
        void Update();

        //chart event handle
        void PanelChartEvent(const int id,const long &lparam, const double &dparam, const string &sparam);
};
void CGraphicalPanel :: CGraphicalPanel(void){}
void CGraphicalPanel :: ~CGraphicalPanel(void){}

bool CGraphicalPanel :: OnInit(void)
{
    //check inputs
    if(!CheckInputs()){return false;}

    //create panel
    if(!this.CreatePanel()){return false;}   //when you call this.CreatePanel() inside another member function of CGraphicalPanel, you're invoking CreatePanel() on the current object, i.e., the object that is calling the function. The this pointer refers to the current object on which the member function is being called.
    return true;
}
bool CGraphicalPanel :: CheckInputs(void)
{
    if(InpPanelWidth<=0){Print("panel width is <=0");return false;}
    if(InpPanelHeight<=0){Print("panel height is <=0");return false;}
    if(InpPanelFontSize<=0){Print("panel fontsieze is <=0");return false;}
    return true;
} 

void CGraphicalPanel :: Update(void)
{
    m_lStart.Text("IStart:      " + (string)InpRangeStart +" " +(InpRangeStart!=0 ? TimeToString(InpRangeStart,TIME_MINUTES) : " "));
    m_lDuration.Text("IDuration:   " + (string)InpRangeDuration+" " +(InpRangeDuration!=0 ? TimeToString(InpRangeDuration,TIME_MINUTES) : " "));
    m_lClose.Text("IClose:      " + (string)InpRangeClose+" " +(InpRangeClose!=0 ? TimeToString(InpRangeClose,TIME_MINUTES) : " "));

}

bool CGraphicalPanel :: CreatePanel(void)
{
    //create dialog panel
    this.Create(NULL,"Time range EA",0,0,0,InpPanelWidth,InpPanelHeight);

    m_lInput.Create(NULL,"Inputs",0,20,10,1,1);
    m_lInput.Text("Inputs");
    m_lInput.Color(clrYellow);
    m_lInput.FontSize(InpPanelFontSize);
    this.Add(m_lInput);

    m_lMagic.Create(NULL,"IMagic",0,20,30,1,1);
    m_lMagic.Text("MagicNumber: " + (string)InpMagicNumber);
    m_lMagic.Color(InpPanelTextColor);
    m_lMagic.FontSize(InpPanelFontSize);
    this.Add(m_lMagic);

    m_lLots.Create(NULL,"ILot",0,20,50,1,1);
    m_lLots.Text("ILot:        " + (string)InpLots);
    m_lLots.Color(InpPanelTextColor);
    m_lLots.FontSize(InpPanelFontSize);
    this.Add(m_lLots);

    m_lStart.Create(NULL,"IStart",0,20,70,1,1);
    m_lStart.Text("IStart:      " + (string)InpRangeStart +" " +(InpRangeStart!=0 ? TimeToString(InpRangeStart,TIME_MINUTES) : " "));
    m_lStart.Color(InpPanelTextColor);
    m_lStart.FontSize(InpPanelFontSize);
    this.Add(m_lStart);

    m_lDuration.Create(NULL,"IDuration",0,20,90,1,1);
    m_lDuration.Text("IDuration:   " + (string)InpRangeDuration+" " +(InpRangeDuration!=0 ? TimeToString(InpRangeDuration,TIME_MINUTES) : " "));
    m_lDuration.Color(InpPanelTextColor);
    m_lDuration.FontSize(InpPanelFontSize);
    this.Add(m_lDuration);

    m_lClose.Create(NULL,"IClose",0,20,110,1,1);
    m_lClose.Text("IClose:      " + (string)InpRangeClose+" " +(InpRangeClose!=0 ? TimeToString(InpRangeClose,TIME_MINUTES) : " "));
    m_lClose.Color(InpPanelTextColor);
    m_lClose.FontSize(InpPanelFontSize);
    this.Add(m_lClose);

    m_bchangeColor.Create(NULL,"button",0,20,150,230,180);
    m_bchangeColor.Text("button");
    m_bchangeColor.Color(clrWhite);
    m_bchangeColor.ColorBackground(clrDarkRed);
    m_bchangeColor.FontSize(InpPanelFontSize);
    this.Add(m_bchangeColor);

    //run panel
    if(!Run()){Print("failed to run panel"); return false;}

    //refresh chart
    ChartRedraw();

    return true; 
}
void CGraphicalPanel :: PanelChartEvent(const int id,const long &lparam, const double &dparam, const string &sparam)
{
    //call chart event method of base class
    ChartEvent(id,lparam,dparam,sparam);

    //check if button was pressed
    if(id==CHARTEVENT_OBJECT_CLICK && sparam=="button")
    {
        OnClickChangeColor();
    }

}
void CGraphicalPanel :: OnClickChangeColor(void)
{
    Print("button pressed");
    ChartSetInteger(NULL,CHART_COLOR_BACKGROUND,m_f_color ? clrWhite : clrAqua);
    m_f_color = !m_f_color;
    ChartRedraw();

}

using System;
using System.Diagnostics;

namespace Cosmic.Core
{
    // Render frames feed an accumulator; integration boundaries do not follow FPS.
    public sealed class TimeController
    {
        readonly NBodyGravitySolver gravity=new NBodyGravitySolver();
        public double PendingSeconds { get; private set; }
        public bool BudgetLimited { get; private set; }
        public void Reset() {PendingSeconds=0;BudgetLimited=false;}
        public double Tick(SimulationEngine engine,double realDelta,double speed,bool paused,int maxSteps=256,double budgetMilliseconds=6)
        {
            if(paused) {Reset();return 0;}
            if(!Numeric.Finite(realDelta) || realDelta<0 || !Numeric.Finite(speed) || speed<=0 || speed>Astronomy.Year)
                throw new ArgumentOutOfRangeException("Invalid clock delta or simulation speed.");
            double incoming=realDelta*speed;
            if(!Numeric.Finite(incoming) || !Numeric.Finite(PendingSeconds+incoming))throw new ArgumentOutOfRangeException("Clock overflow.");
            PendingSeconds+=incoming;double actual=0;int steps=0;
            long started=Stopwatch.GetTimestamp();BudgetLimited=false;
            while(steps<maxSteps)
            {
                double quantum=Math.Min(gravity.StableStep(engine.Bodies),Math.Max(1e-6,speed/120));
                if(!Numeric.Finite(quantum) || quantum<=0)break;
                if(PendingSeconds+Math.Max(1e-10,quantum*1e-12)<quantum)break;
                if(steps>0 && budgetMilliseconds>0 && (Stopwatch.GetTimestamp()-started)*1000.0/Stopwatch.Frequency>=budgetMilliseconds) {BudgetLimited=true;break;}
                double completed=engine.Advance(quantum,1,0);if(completed<=0)break;
                PendingSeconds=Math.Max(0,PendingSeconds-completed);actual+=completed;steps++;
            }
            if(steps==maxSteps && PendingSeconds>=Math.Min(gravity.StableStep(engine.Bodies),Math.Max(1e-6,speed/120)))BudgetLimited=true;
            return actual;
        }
    }
}

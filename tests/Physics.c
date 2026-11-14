#include "../Sources/AxsDaFeiYuPetPhysics.h"
#include <assert.h>
#include <stdio.h>
int main(void) {
    assert(axs_dafeiyupet_clamp(NAN,0,1)==0);
    assert(axs_dafeiyupet_clamp(200,100,300)==200);
    assert(axs_dafeiyupet_clamp(-1,.2,1)==.2);
    assert(fabs(axs_dafeiyupet_release(100000))<=3600);
    assert(axs_dafeiyupet_release(NAN)==0);
    AxsDaFeiYuPetBody b={20,20,1300,-2000};
    for(int i=0;i<20000;i++) { axs_dafeiyupet_step(&b,.016,200,600); assert(b.x>=0 && b.x<=200 && b.y>=0 && b.y<=600); }
    assert(b.vx==0 && b.vy==0);
    b=(AxsDaFeiYuPetBody){1,1,0,0}; axs_dafeiyupet_step(&b,100,200,600); assert(b.y<10);
    b=(AxsDaFeiYuPetBody){1,1,0,0}; axs_dafeiyupet_step(&b,.01,0,0); assert(b.x==0&&b.y==0);
    puts("PASS physics: clamp, nonfinite config, throw cap, 20k steps, rest, dt, zero bounds");
}

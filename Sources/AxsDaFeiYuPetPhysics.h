#pragma once
#include <math.h>
// Native point-space adaptation of shared/physics.ts; bounded dt, restitution and friction.
typedef struct { double x,y,vx,vy; } AxsDaFeiYuPetBody;
static inline double axs_dafeiyupet_clamp(double v,double lo,double hi) {
    return isfinite(v) ? fmin(fmax(v,lo),hi) : lo;
}
static inline void axs_dafeiyupet_step(AxsDaFeiYuPetBody *b,double dt,double w,double h) {
    dt=axs_dafeiyupet_clamp(dt,0,0.05); w=fmax(0,w); h=fmax(0,h);
    b->vy+=1400*dt; b->x+=b->vx*dt; b->y+=b->vy*dt;
    if(b->x<0) { b->x=0; b->vx=fabs(b->vx)*0.78; }
    if(b->x>w) { b->x=w; b->vx=-fabs(b->vx)*0.78; }
    if(b->y<0) { b->y=0; b->vy=fabs(b->vy)*0.78; }
    if(b->y>=h) { b->y=h; b->vy=-fabs(b->vy)*0.78;
        if(fabs(b->vy)<40) b->vy=0;
        b->vx*=exp(-2.5*dt); if(fabs(b->vx)<15) b->vx=0;
    }
}
static inline double axs_dafeiyupet_release(double v) {
    return isfinite(v) ? copysign(3600*(1-exp(-fabs(v)/3600)),v) : 0;
}

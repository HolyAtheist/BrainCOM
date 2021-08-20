//data/blobby2.glsl 
//baseret på blobby.glsl fra genekogans shader eksempler 
//https://github.com/genekogan/Processing-Shader-Examples 
 
#define PROCESSING_COLOR_SHADER 
 
#ifdef GL_ES 
precision mediump float; 
#endif 
 
uniform float time;  //movement 
uniform vec2 resolution; 
uniform float depth; 
uniform float rate; 
uniform float alpha; 
uniform float colr; 
uniform float colg; 
uniform float colb; 
 
#define N 16 
 
void main( void ) { 
    vec2 v=(gl_FragCoord.xy-(resolution*0.5))/min(resolution.y,resolution.x)*10.0; 
    float t=time * 0.3,r=2.0; 
    for (int i=1;i<N;i++){ 
     float d=(3.14159265 / float(N))*(float(i)*14.0); 
     r+=length(vec2(rate*v.y,rate*v.x))+1.21; 
     v = vec2(v.x+cos(v.y+cos(r)+d)+cos(t),v.y-sin(v.x+cos(r)+d)+sin(t)); 
    } 
     r = (sin(r*0.09)*0.5)+0.5; 
    r = pow(r, depth); 
    gl_FragColor = vec4(pow(max(r-colr,0.0)*2,4),pow(max(r-colg,0.0)*2,4),pow(max(r-colb,0.1)*2,4), alpha ); 
} 
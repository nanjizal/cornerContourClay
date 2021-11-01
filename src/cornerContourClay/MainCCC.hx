package cornerContourClay;

import clay.opengl.GL;
import clay.buffers.Float32Array;
import clay.graphics.Shader;
import clay.graphics.Graphics;
import clay.Clay;

#if js
import htmlHelper.tools.DivertTrace;
#end

// contour code
import cornerContour.Sketcher;
import cornerContour.SketcherGrad;
import cornerContour.IPen;
import cornerContour.Pen2D;
import cornerContour.Pen2DGrad;
import cornerContour.StyleSketch;
import cornerContour.StyleEndLine;
// SVG path parser
import justPath.*;
import justPath.transform.ScaleContext;
import justPath.transform.ScaleTranslateContext;
import justPath.transform.TranslationContext;

using StringTools;

class CCCEvents extends clay.Events {

    public function new() {}

    override function tick(delta:Float) {
        
        MainCCC.draw();

    }

    override function ready():Void {

        MainCCC.ready();

    }

}

@:allow(cornerContour.CCCEvents)
class MainCCC {
    #if js
    static var divertTrace:             DivertTrace;
    #end
    static var events:CCCEvents;

    static var vertShaderData:String ='
attribute vec3 vertexPosition;
attribute vec4 vertexColor;

varying vec4 color;

uniform mat4 projectionMatrix;
uniform mat4 modelViewMatrix;

void main(void) {

    gl_Position = vec4(vertexPosition, 1.0);
    color = vertexColor;
    gl_PointSize = 1.0;

}
'.trim();

    static var fragShaderData:String = '
#ifdef GL_ES
precision mediump float;
#else
#define mediump
#endif

varying vec4 color;

void main() {
    gl_FragColor = color;
}
'.trim();

    static var shader:Shader;
    
    // cornerContour specific code
    static var sketcher:       SketcherGrad;
    static var pen2D:          Pen2DGrad;
     
     // general
     static var width:            Int;
     static var height:           Int ;
     static var vertices: clay.buffers.Float32Array;
     static var colors: clay.buffers.Float32Array;
     static var totalLen: Int;
    public static function main():Void {
        #if js
        divertTrace = new DivertTrace();
        #end
        trace( 'cornerContour clay demo');
        events = @:privateAccess new CCCEvents();
        @:privateAccess new Clay(configure, events);
        
    }

    static function configure(config:clay.Config) {

        config.window.resizable = true;

        config.render.stencil = 2;
        config.render.depth = 16;

    }
    static var chooseColors = new Array<Int>();
    static var chooseI = 0;
    public static function ready():Void {
        
        width  = Clay.app.screenWidth;
        height = Clay.app.screenHeight;
        pen2D = new Pen2DGrad( 0xFF0000FF, 0xFF00FF00, 0xFF0000FF );
        pen2D.currentColor = 0xFF0000FF;
        pen2D.colorB = 0xFF00FF00;
        pen2D.colorC = 0xFF0000FF;
        var styleEnd = StyleEndLine.ellipseBoth;
        sketcher = new SketcherGrad( pen2D, StyleSketch.Fine, styleEnd ) ;
        var x0 = 0.;
        var y0 = 0.;
        var pw = 20;
        var penWidth = pw;
        sketcher.contour.endCapFactor = 0.6;
        for( i in 0...20 ){
            x0 = 200 + 160*Math.sin( i* Math.PI*2/20 );
            y0 = 200 - 160*Math.cos( i* Math.PI*2/20 );
            penWidth += 1;
            chooseColors[chooseI] = 0xFF000000 + Std.random( 0xFFFFFF );
            pen2D.currentColor = chooseI++;
            chooseColors[chooseI] = 0xFF000000 + Std.random( 0xFFFFFF );
            pen2D.colorB = chooseI++;
            sketcher.setPosition( x0, y0 )
                    .penSize( penWidth/4 )
                    .setAngle( i*180/10 + 180 )
                    .forward( 80 )
                    .forward( 10 ) // bug in contourGradient call twice to resolve for now.
                    .moveTo( 0,0 );
        }
        penWidth = pw;
        sketcher.contour.endCapFactor = 0.2;
        for( i in 0...20 ){
            x0 = 420 + 160*Math.sin( i* Math.PI*2/20 );
            y0 = 420 - 160*Math.cos( i* Math.PI*2/20 );
            penWidth += 1;
            sketcher.contour.endCapFactor += 0.2;
            chooseColors[chooseI] = 0xFF000000 + Std.random( 0xFFFFFF );
            pen2D.currentColor = chooseI++;
            chooseColors[chooseI] = 0xFF000000 + Std.random( 0xFFFFFF );
            pen2D.colorB = chooseI++;
            sketcher.setPosition( x0, y0 )
            .penSize( penWidth/4 )
            .setAngle( i*180/10 + 180 )
            .forward( 80 )
            .forward( 10 ) // bug in contourGradient call twice to resolve for now.
            .moveTo( 0, 0 );
        }
        var data = get_xyzw_rgba_array( pen2D.arr );
        vertices = Float32Array.fromArray( data.xyzw );
        colors   = Float32Array.fromArray( data.rgba );
        totalLen = 3*pen2D.arr.size;
        
        trace('Create shader');
        shader = new Shader();
        shader.vertSource = vertShaderData;
        shader.fragSource = fragShaderData;
        shader.attributes = ['vertexPosition', 'vertexColor'];
        shader.init();
        trace('Did init shader');
        shader.activate();

    }

    public static inline
    function alphaChannel( int: Int ) : Float
        return ((int >> 24) & 255) / 255;
    public static inline
    function redChannel( int: Int ) : Float
        return ((int >> 16) & 255) / 255;
    public static inline
    function greenChannel( int: Int ) : Float
        return ((int >> 8) & 255) / 255;
    public static inline
    function blueChannel( int: Int ) : Float
        return (int & 255) / 255;
        
    static function get_xyzw_rgba_array( data: cornerContour.io.Array2DTriGrad ){
        var vert = new Array<Float>();
        var col = new Array<Float>();
        var v = 0;
        var c = 0;
        for( i in 0...data.size ){
            data.pos = i;
            vert[ v++ ] = gx( data.ax );
            vert[ v++ ] = gy( data.ay );
            vert[ v++ ] = 0.;
            vert[ v++ ] = 1.;
            vert[ v++ ] = gx( data.bx );
            vert[ v++ ] = gy( data.by );
            vert[ v++ ] = 0.;
            vert[ v++ ] = 1.;
            vert[ v++ ] = gx( data.cx );
            vert[ v++ ] = gy( data.cy );
            vert[ v++ ] = 0.;
            vert[ v++ ] = 1.;
            var colInt = data.colorIntA;
            col[ c++ ] = redChannel(   colInt );
            col[ c++ ] = greenChannel( colInt );
            col[ c++ ] = blueChannel(  colInt );
            col[ c++ ] = alphaChannel( colInt );
            colInt = data.colorIntB;
            col[ c++ ] = redChannel(   colInt );
            col[ c++ ] = greenChannel( colInt );
            col[ c++ ] = blueChannel(  colInt );
            col[ c++ ] = alphaChannel( colInt );
            colInt = data.colorIntC;
            col[ c++ ] = redChannel(   colInt );
            col[ c++ ] = greenChannel( colInt );
            col[ c++ ] = blueChannel(  colInt );
            col[ c++ ] = alphaChannel( colInt );
        }
        return { xyzw: vert, rgba: col };
    }
    public static inline
    function gx( v: Float ): Float {
        return -( 1 - 2*v/width );
    }
    public static inline
    function gy( v: Float ): Float {
        return ( 1 - 2*v/height );
    }
    static var theta = 0.;
    public static function draw():Void {
        #if animateCircles
        width  = Clay.app.screenWidth;
        height = Clay.app.screenHeight;
        pen2D = new Pen2DGrad( 0xFF0000FF, 0xFF00FF00, 0xFF0000FF );
        pen2D.currentColor = 0xFF0000FF;
        pen2D.colorB = 0xFF00FF00;
        pen2D.colorC = 0xFF0000FF;
        var styleEnd = StyleEndLine.ellipseBoth;
        sketcher = new SketcherGrad( pen2D, StyleSketch.Fine, styleEnd ) ;
        var x0 = 0.;
        var y0 = 0.;
        var pw = 25;
        var penWidth = pw;
        chooseI = 0;
        sketcher.contour.endCapFactor = 0.6;
        for( i in 0...20 ){
            x0 = 200 + 160*Math.sin( i* Math.PI*2/20 + theta );
            y0 = 200 - 160*Math.cos( i* Math.PI*2/20 + theta );
            penWidth += 1;
            pen2D.currentColor = chooseColors[ chooseI++ ];
            pen2D.colorB = chooseColors[ chooseI++ ];
            sketcher.setPosition( x0, y0 )
                    .penSize( penWidth/4 )
                    .setAngle( i*180/10 + 180 )
                    .forward(50 )
                    .arc( 50, 120 )
                    .forward( 10 ) // bug in contourGradient call twice to resolve for now.
                    .moveTo( 0,0 );
        }
        penWidth = pw;
        sketcher.contour.endCapFactor = 0.2;
        for( i in 0...20 ){
            x0 = 420 + 160*Math.sin( i* Math.PI*2/20 + theta );
            y0 = 420 - 160*Math.cos( i* Math.PI*2/20 + theta );
            penWidth += 1;
            sketcher.contour.endCapFactor += 0.2;
            chooseColors[ chooseI ] = chooseColors[ chooseI ]+ 0x00030000;
            pen2D.currentColor = chooseColors[ chooseI++ ];
            chooseColors[ chooseI ] = chooseColors[ chooseI ] - 0x00010003;
            pen2D.colorB = chooseColors[ chooseI++ ];
            sketcher.setPosition( x0, y0 )
            .penSize( penWidth/4 )
            .setAngle( i*180/10 + 180 )
            .forward( 80 )
            .forward( 10 ) // bug in contourGradient call twice to resolve for now.
            .moveTo( 0, 0 );
        }
        theta += 0.03;
        var data = get_xyzw_rgba_array( pen2D.arr );
        vertices = Float32Array.fromArray( data.xyzw );
        colors   = Float32Array.fromArray( data.rgba );
        totalLen = 3*pen2D.arr.size;
        #end


        Graphics.clear(0.25, 0.25, 0.25, 1);
        Graphics.setViewport(
            0, 0,
            Std.int(Clay.app.screenWidth * Clay.app.screenDensity),
            Std.int(Clay.app.screenHeight * Clay.app.screenDensity)
        );
        
        GL.enableVertexAttribArray(0);
        GL.enableVertexAttribArray(1);

        var verticesBuffer = GL.createBuffer();
        GL.bindBuffer(GL.ARRAY_BUFFER, verticesBuffer);
        GL.bufferData(GL.ARRAY_BUFFER, vertices, GL.STREAM_DRAW);
        GL.vertexAttribPointer(0, 4, GL.FLOAT, false, 0, 0);

        var colorsBuffer = GL.createBuffer();
        GL.bindBuffer(GL.ARRAY_BUFFER, colorsBuffer);
        GL.bufferData(GL.ARRAY_BUFFER, colors, GL.STREAM_DRAW);
        GL.vertexAttribPointer(1, 4, GL.FLOAT, false, 0, 0);

        GL.drawArrays(GL.TRIANGLES, 0, totalLen);

        GL.deleteBuffer(verticesBuffer);
        GL.deleteBuffer(colorsBuffer);

        GL.disableVertexAttribArray(0);
        GL.disableVertexAttribArray(1);

        Graphics.ensureNoError();

    }

}
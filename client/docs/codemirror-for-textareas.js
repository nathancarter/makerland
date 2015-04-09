$( '.code' ).each( function ( index, e ) {
    $( e ).addClass( 'cm-s-default' );
    var content = e.textContent;
    var lines = content.split( '\n' );
    while ( ( lines.length > 0 ) && ( lines[0].trim().length == 0 ) )
        lines.shift();
    while ( ( lines.length > 0 )
         && ( lines[lines.length-1].trim().length == 0 ) )
        lines.pop();
    if ( lines.length > 0 ) {
        function indentOfLine ( line ) {
            var result = /^(\s+)/.exec( lines[0] );
            return result ? result[1].length : 0;
        }
        var min = indentOfLine( lines[0] );
        for ( var i = 1 ; i < lines.length ; i++ )
            min = Math.min( min, indentOfLine( lines[i] ) );
        for ( var i = 0 ; i < lines.length ; i++ )
            lines[i] = lines[i].substring( min );
        e.textContent = lines.join( '\n' );
    }
    var newElement = CodeMirror.fromTextArea( e, {
        readOnly : 'nocursor',
        lineNumbers : true,
        indentUnit : 4
    } );
    var newheight = newElement.heightAtLine( lines.length, 'local' );
    newElement.setSize( null, newheight );
    var wrapper = document.createElement( 'div' );
    wrapper.style.border = 'solid 1px gray';
    console.log( newElement );
    var thing = newElement.getWrapperElement();
    thing.parentNode.replaceChild( wrapper, thing );
    wrapper.appendChild( thing );
} );

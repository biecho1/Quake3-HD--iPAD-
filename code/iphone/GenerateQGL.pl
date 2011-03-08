#!/usr/bin/perl

open(INPUT_FILE, ">/tmp/input-$$.h") || die "$!";
print INPUT_FILE "#import <OpenGLES/gl.h>\n";
close INPUT_FILE;
open(CPP, "/usr/local/bin/arm-apple-darwin-cpp /tmp/input-$$.h|") || die "$!";

print "/**** This file is autogenerated.  Run GenerateQGL.pl to update it ****/\n\n";

print "#ifdef QGL_LOG_GL_CALLS\n";
print "extern unsigned int QGLLogGLCalls;\n";
print "extern FILE *QGLDebugFile(void);\n";
print "#endif\n\n";

print "extern void QGLCheckError(const char *message);\n";
print "extern unsigned int QGLBeginStarted;\n\n";
print "// This has to be done to avoid infinite recursion between our glGetError wrapper and QGLCheckError()\n";
print "static inline GLenum _glGetError(void) {\n";
print "    return glGetError();\n";
print "}\n\n";

@functionNames = ();

while (<CPP>) {
    chop;
    /^extern/ || next;
    s/extern //;
    print "// $_\n";

    # This approach is necessary to deal with glGetString whos type isn't a single word
    ($type, $rest) = m/(.+)\s+(gl.*)/;
#    print "type='$type'\n";
#    print "rest='$rest'\n";

    ($name, $argString) = ($rest =~ m/(\w+).*\s*\((.*)\)/);
	next if ($name eq "glColor4f");
    $isVoid = ($type =~ m/void/);
    push(@functionNames, $name);

#    print "name=$name\n";
#    print "argString=$argString\n";
#    print "argCount=$#args\n";

    # Parse the argument list into two arrays, one of types and one of argument names
    if ($argString =~ m/^void$/) {
        @args = ();
    } else {
        @args = split(",", $argString);
    }
    @argTypes = ();
    @argNames = ();
    for $arg (@args) {
        ($argType, $argName) = ($arg =~ m/(.*[ \*])([_a-zA-Z0-9]+)/);
        $argType =~ s/^ *//;
        $argType =~ s/ *$//;

        push(@argTypes, $argType);
        push(@argNames, $argName);
#        print "argType='$argType'\n";
#        print "argName='$argName'\n";
    }


    print "static inline $type q$name($argString)\n";
    print "{\n";

    if (! $isVoid) {
        print "    $type returnValue;\n";
    }

    print "#if !defined(NDEBUG) && defined(QGL_LOG_GL_CALLS)\n";
    print "    if (QGLLogGLCalls)\n";
    print "        fprintf(QGLDebugFile(), \"$name(";

    if ($#argTypes >= 0) {
        for ($i = 0; $i <= $#argTypes; $i++) {
            $argType = $argTypes[$i];
            $argName = $argNames[$i];
            $_ = $argType;
            if (/^GLenum$/ || /^GLuint$/ || /^GLbitfield$/) {
                print "$argName=%lu";
            } elsif (/^GLsizei$/ || /^GLint$/ || /^GLsizeiptr$/ || /^GLintptr$/ || /^GLfixed$/ || /^GLclampx$/) {
                print "$argName=%ld";
            } elsif (/^GLfloat$/ || /^GLdouble$/ || /^GLclampf$/ || /^GLclampd$/) {
                print "$argName=%f";
            } elsif (/^GLbyte$/) {
                print "$argName=%d";
            } elsif (/^GLubyte$/) {
                print "$argName=%u";
            } elsif (/^GLshort$/) {
                print "$argName=%d";
            } elsif (/^GLushort$/) {
                print "$argName=%u";
            } elsif (/^GLboolean$/) {
                print "$argName=%u";
            } elsif (/\*$/) {
                # TJW -- Later we should look at the count specified in the function name, look at the basic type and print out an array.  Or we could just special case them...
                print "$argName=%p";
            } else {
                print STDERR "Unknown type '$argType'\n";
                exit(1);
            }

            print ", " if ($i != $#argTypes);
        }
    } else {
        print "void";
    }

    print ")\\n\"";
    print ", " if $#argTypes >= 0;
    print join(", ", @argNames);
    print ");\n";
    print "#endif\n";

    if (! $isVoid) {
        print "    returnValue = ";
    } else {
        print "    ";
    }
    print "$name(" . join(", ", @argNames) . ");\n";

    print "#if !defined(NDEBUG) && defined(QGL_CHECK_GL_ERRORS)\n";
    if ($name eq "glBegin") {
        print "    QGLBeginStarted++;\n";
    }
    if ($name eq "glEnd") {
        print "    QGLBeginStarted--;\n";
    }
    print "    if (!QGLBeginStarted)\n";
    print "        QGLCheckError(\"$name\");\n";
    print "#endif\n";

    if (! $isVoid) {
        print "    return returnValue;\n";
    }
    
    print "}\n\n";
}


print "// Prevent calls to the 'normal' GL functions\n";
for $name (@functionNames) {
    print "#define $name CALL_THE_QGL_VERSION_OF_$name\n";
}


/* This should be discarded.  */

  /* This should be kept.  */
  my $foo = 'bar';

%s PATTERN FOOBAR
%%
<PATTERN,FOOBAR>abcdef          print "foobar!\n"; return $^N;
<PATTERN>jdsdlkfs               {
                                        print "Hello, world!\n";
                                }
<PATTERN>sdklfds                %{
                                        print "Hello, world!\n";
                                %}
%%
print "Hello, world!\n";

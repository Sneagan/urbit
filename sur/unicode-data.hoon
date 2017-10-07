|%
++  line
  :>    an individual codepoint definition
  :>
  :>  code: the codepoint in hexadecimal format
  :>  name: the character name
  :>  gen: the type of character this is
  :>  can: the canonical combining class for ordering algorithms
  :>  bidi: the bidirectional category of this character
  :>  de: the character decomposition mapping
  :>  decimal: the decimal digit value (or ~)
  :>  digit: the digit value, covering non decimal radix forms
  :>  numeric: the numeric value, including fractions
  :>  mirrored: whether char is mirrored in bidirectional text
  :>  old-name: unicode 1.0 compatibility name
  :>  iso: iso 10646 comment field
  :>  up: uppercase mapping codepoint
  :>  low: lowercase mapping codepoint
  :>  title: titlecase mapping codepoint
  :>
  $:  code/@c
      name/tape
      gen/general
      can/@ud
      bi/bidi
      de/decomp
      ::  todo: decimal/digit/numeric need to be parsed.
      decimal/tape
      digit/tape
      numeric/tape
      mirrored/?
      old-name/tape
      iso/tape
      up/(unit @c)
      low/(unit @c)
      title/(unit @c)
  ==
::
++  general
  :>    one of the normative or informative unicode general categories
  :>
  :>  these abbreviations are as found in the unicode standard, except
  :>  lowercased as to be valid symbols.
  $?  $lu  :<  letter, uppercase
      $ll  :<  letter, lowercase
      $lt  :<  letter, titlecase
      $mn  :<  mark, non-spacing
      $mc  :<  mark, spacing combining
      $me  :<  mark, enclosing
      $nd  :<  number, decimal digit
      $nl  :<  number, letter
      $no  :<  number, other
      $zs  :<  separator, space
      $zl  :<  separator, line
      $zp  :<  separator, paragraph
      $cc  :<  other, control
      $cf  :<  other, format
      $cs  :<  other, surrogate
      $co  :<  other, private use
      $cn  :<  other, not assigned
      ::
      $lm  :<  letter, modifier
      $lo  :<  letter, other
      $pc  :<  punctuation, connector
      $pd  :<  punctuation, dash
      $ps  :<  punctuation, open
      $pe  :<  punctuation, close
      $pi  :<  punctuation, initial quote
      $pf  :<  punctuation, final quote
      $po  :<  punctuation, other
      $sm  :<  symbol, math
      $sc  :<  symbol, currency
      $sk  :<  symbol, modifier
      $so  :<  symbol, other
  ==
::
++  bidi
  :>  bidirectional category of a unicode character
  $?  $l    :<  left-to-right
      $lre  :<  left-to-right embedding
      $lri  :<  left-to-right isolate
      $lro  :<  left-to-right override
      $fsi  :<  first strong isolate
      $r    :<  right-to-left
      $al   :<  right-to-left arabic
      $rle  :<  right-to-left embedding
      $rli  :<  right-to-left isolate
      $rlo  :<  right-to-left override
      $pdf  :<  pop directional format
      $pdi  :<  pop directional isolate
      $en   :<  european number
      $es   :<  european number separator
      $et   :<  european number terminator
      $an   :<  arabic number
      $cs   :<  common number separator
      $nsm  :<  non-spacing mark
      $bn   :<  boundary neutral
      $b    :<  paragraph separator
      $s    :<  segment separator
      $ws   :<  whitespace
      $on   :<  other neutrals
  ==
::
++  decomp
  :>  character decomposition mapping.
  :>
  :>  tag: type of decomposition.
  :>  c: a list of codepoints this decomposes into.
  (unit {tag/(unit decomp-tag) c/(list @c)})
::
++  decomp-tag
  :>  tag that describes the type of a character decomposition.
  $?  $font      :<  a font variant
      $no-break  :<  a no-break version of a space or hyphen
      $initial   :<  an initial presentation form (arabic)
      $medial    :<  a medial presentation form (arabic)
      $final     :<  a final presentation form (arabic)
      $isolated  :<  an isolated presentation form (arabic)
      $circle    :<  an encircled form
      $super     :<  a superscript form
      $sub       :<  a subscript form
      $vertical  :<  a vertical layout presentation form
      $wide      :<  a wide (or zenkaku) compatibility character
      $narrow    :<  a narrow (or hankaku) compatibility character
      $small     :<  a small variant form (cns compatibility)
      $square    :<  a cjk squared font variant
      $fraction  :<  a vulgar fraction form
      $compat    :<  otherwise unspecified compatibility character
  ==
--

.segment "HEADER"
.byte $4e, $45, $53, $1a  ; magic string for iNES header
.byte $02                 ; number of 16KB PRG-ROM banks
.byte $01                 ; number of 8KB CHR-ROM banks
.byte %00000001           ; vertical mirrorin, no save RAM, no mapper
.byte %00000000           ; no special-case flags set, no mapper
.byte $00                 ; no PRG-RAM present
.byte $00                 ; NTSC format

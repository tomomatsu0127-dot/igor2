#pragma rtGlobals=3
// Apply typography at the graph boundary, keeping the editable labels plain.
Function/S XRD132_CompositionLabel(label)
    String label
    if(strsearch(label,num2char(92),0)>=0)
        return label
    endif
    String prefix="",sign="",value="",suffix=""
    String pattern="(?s)^((?:.*?[^\\p{L}\\p{N}_])?)x[ \\t]*=[ \\t]*([+−－-]?)[ \\t]*((?:[0-9]+(?:[.][0-9]*)?|[.][0-9]+)(?:[eE][+−－-]?[0-9]+)?)(.*)$"
    SplitString/E=(pattern) label,prefix,sign,value,suffix
    if(V_flag!=4)
        return label
    endif
    if(strlen(sign) && cmpstr(sign,"+")!=0)
        sign="−"
    endif
    value=ReplaceString("－",ReplaceString("-",value,"−"),"−")
    return prefix+"\\f02x\\f00 = "+sign+value+suffix
End

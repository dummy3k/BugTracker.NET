<td nowrap valign=middle>
    <form style='margin: 0px; padding: 0px;' action=search_text.aspx method=get onsubmit='return on_submit_search()'>
        <input class=menubtn type=submit value='$SearchText()$'>
        <input class=menuinput  id=lucene_input size=12 type=text class=txt
        value='$query$'name=query accesskey=s>
        <a href=lucene_syntax.html target=_blank style='font-size: 7pt;'>$Advanced()$</a>
    </form>
</td>

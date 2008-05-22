<%@ Page language="C#"%>
<!-- #include file = "inc.aspx" -->

<script language="C#" runat="server">

    class TagLabel : IComparable<TagLabel>
    {
        public int count;
        public string label;
        public int CompareTo(TagLabel other)
        {
            if (this.count > other.count)
                return -1;
            else if (this.count < other.count)
                return 1;
            else
                return 0;
        }
    }
    
    
///////////////////////////////////////////////////////////////////////
void Page_Load(Object sender, EventArgs e)
{
	Util.do_not_cache(Response);
    DbUtil dbutil = new DbUtil();
}

void print_tags()
{
    SortedDictionary<string, List<int>> tags =
        (SortedDictionary<string, List<int>>)Application["tags"];

    System.Collections.Generic.List<TagLabel> tags_by_count = new
        System.Collections.Generic.List<TagLabel>();

    foreach (string s in tags.Keys)
    {
        Response.Write("<tr><td class=datad>");
        Response.Write("<a href='javascript:opener.append_tag(\"");

        Response.Write(s);

        Response.Write("\")'>");

        Response.Write(s);

        Response.Write("</a><td class=datad>");
        Response.Write(tags[s].Count);
    }
}    
    
</script>
<html>
<head>
<title>Tags</title>
<script>
function do_unload()
{
    opener.done_selecting_tags()
}
</script>
<link rel="StyleSheet" href="btnet.css" type="text/css">
</head>
<body onunload="do_unload()">
<table border=1 class=datat>
<tr><td class=datah>tag</td><td class=datah>count</td>
</tr>
<% print_tags(); %>
</table>
</body>
</html>
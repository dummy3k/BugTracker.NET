<%@ Page language="C#"%>
<!--
Copyright 2002-2008 Corey Trager
Distributed under the terms of the GNU General Public License
-->
<!-- #include file = "inc.aspx" -->

<script language="C#" runat="server">


///////////////////////////////////////////////////////////////////////
void Page_Load(Object sender, EventArgs e)
{
	Util.do_not_cache(Response);

	if (Util.get_setting("EnableWhatsNewPage","0") == "0")
	{
		Response.Write("Sorry, Web.config EnableWhatsNewPage is set to 0");
		Response.End();
	}

	List<BugNews> list = (List<BugNews>) Application["whatsnew"];
	if (list == null)
	{
		Response.Write("no news");
		Response.End();
	}

	StringBuilder sb = new StringBuilder();

	sb.Append("<table border=1 class=datat><tr>");
	sb.Append("<td class=datah>when");
	sb.Append("<td class=datah>id");
	sb.Append("<td class=datah>desc");
	sb.Append("<td class=datah>action");
	sb.Append("<td class=datah>user");

	long ticks_now = DateTime.Now.Ticks;

	for (int i = list.Count - 1; i > -1; i--)
	{
		if (i == list.Count-101)
		{
			break; // just the most recent 100
		}

		BugNews news = list[i];

		sb.Append("<tr>");

		TimeSpan ts = new TimeSpan(ticks_now - news.when.Ticks);

		if (ts.TotalSeconds < 90)
		{
			sb.Append("<td class=datad style='background:red;'>");
		}
		else if (ts.TotalSeconds < 180)
		{
			sb.Append("<td class=datad style='background:orange;'>");
		}
		else if (ts.TotalSeconds < 300)
		{
			sb.Append("<td class=datad style='background:yellow;'>");
		}
		else
		{
			sb.Append("<td class=datad>");
		}
		sb.Append(btnet.Util.how_long_ago(ts));

		sb.Append("<td class=datad>");
		sb.Append(Convert.ToString(news.id));

		sb.Append("<td class=datad><a href=edit_bug.aspx?id=");
		sb.Append(Convert.ToString(news.id));
		sb.Append(">");
		sb.Append(news.desc);
		sb.Append("</a>");

		sb.Append("<td class=datad>");
		sb.Append(news.action);

		sb.Append("<td class=datad>");
		sb.Append(news.who);

	}

	sb.Append("</table>");
	Response.Write(sb.ToString());

}


</script>
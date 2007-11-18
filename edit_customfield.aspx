<%@ Page language="C#"%>
<!--
Copyright 2002-2007 Corey Trager
Distributed under the terms of the GNU General Public License
-->
<!-- #include file = "inc.aspx" -->

<script language="C#" runat="server">

int id;
String sql;

DbUtil dbutil;
Security security;


///////////////////////////////////////////////////////////////////////
void Page_Load(Object sender, EventArgs e)
{

	Util.do_not_cache(Response);
	dbutil = new DbUtil();
	security = new Security();
	security.check_security(dbutil, HttpContext.Current, Security.MUST_BE_ADMIN);

	titl.InnerText = Util.get_setting("AppTitle","BugTracker.NET") + " - "
		+ "edit custom column metadata";

	msg.InnerText = "";

	id = Convert.ToInt32(Util.sanitize_integer(Request["id"]));

	if (!IsPostBack)
	{

		// Get this entry's data from the db and fill in the form

		sql = @"select sc.name, isnull(ccm_dropdown_vals,'') [vals],
			isnull(ccm_dropdown_type,'') [dropdown_type],
			isnull(ccm_sort_seq, sc.colorder) [column order]
			from syscolumns sc
			inner join sysobjects so on sc.id = so.id
			left outer join custom_col_metadata ccm on ccm_colorder = sc.colorder
			where so.name = 'bugs'
			and sc.colorder = $co";

		sql = sql.Replace("$co", Convert.ToString(id));
		DataRow dr = dbutil.get_datarow(sql);

		name.InnerText = (string) dr["name"];


		// Fill in this form
		vals.Value = (string) dr["vals"];
		sort_seq.Value = Convert.ToString(dr["column order"]);
		dropdown_type.Items.Insert(0, new ListItem("not a dropdown",""));
		dropdown_type.Items.Insert(1, new ListItem("normal","normal"));
		dropdown_type.Items.Insert(2, new ListItem("users","users"));

		foreach (ListItem li in dropdown_type.Items)
		{
			if (li.Text == Convert.ToString(dr["dropdown_type"]))
			{
				li.Selected = true;
			}
			else
			{
				li.Selected = false;
			}
		}


	}

}


///////////////////////////////////////////////////////////////////////
Boolean validate()
{

	Boolean good = true;

	if (sort_seq.Value == "")
	{
		good = false;
		sort_seq_err.InnerText = "Sort Sequence is required.";
	}
	else
	{
		sort_seq_err.InnerText = "";
	}


	if (!Util.is_int(sort_seq.Value))
	{
		good = false;
		sort_seq_err.InnerText = "Sort Sequence must be an integer.";
	}
	else
	{
		sort_seq_err.InnerText = "";
	}


	return good;
}

///////////////////////////////////////////////////////////////////////
void on_update (Object sender, EventArgs e)
{

	Boolean good = validate();

	if (good)
	{

		sql = @"declare @count int
			select @count = count(1) from custom_col_metadata
			where ccm_colorder = $co

			if @count = 0
				insert into custom_col_metadata
				(ccm_colorder, ccm_dropdown_vals, ccm_sort_seq, ccm_dropdown_type)
				values($co, '$v', $ss, '$dt')
			else
				update custom_col_metadata
				set ccm_dropdown_vals = '$v',
				ccm_sort_seq = $ss,
				ccm_dropdown_type = '$dt'
				where ccm_colorder = $co";

		sql = sql.Replace("$co", Convert.ToString(id));
		sql = sql.Replace("$v", vals.Value.Replace("'", "''"));
		sql = sql.Replace("$ss", sort_seq.Value);
		sql = sql.Replace("$dt", dropdown_type.SelectedItem.Value.Replace("'", "''"));


		dbutil.execute_nonquery(sql);
		Server.Transfer ("customfields.aspx");
	}
	else
	{
		msg.InnerText = "dropdown values were not updated.";
	}

}

</script>

<html>
<head>
<title id="titl" runat="server">btnet edit val</title>
<link rel="StyleSheet" href="btnet.css" type="text/css">
</head>
<body>
<% security.write_menu(Response, Util.get_setting("PluralBugLabel","bugs")); %>


<div class=align><table border=0><tr><td>
<a href=customfields.aspx>back to custom fields</a><p>
<form class=frm runat="server">
	<table border=0>

	<tr>
	<td colspan=3>
	Field Name:&nbsp;<span class=smallnote style="font-size: 12pt; font-weight: bold;" id="name" runat="server">
	</span>
	</td>
	</tr>

	<tr>
	<td colspan=3>
	&nbsp;
	</td>
	</tr>

	<tr>
	<td colspan=3>
	<span class=smallnote>
	A dropdown type of "normal" uses the values specified in "Normal Dropdown Values" below.
	<br>A dropdown type of "users" is filled with values from the users table.
	<br>The same list that is used for "assigned to" will be used for a "user" dropdown.
	</span>
	</td>
	</tr>

	<tr>
	<td class=lbl>Dropdown Type:</td>
	<td><asp:DropDownList id="dropdown_type" runat="server">
	</asp:DropDownList></td>
	<td>&nbsp</td>
	</tr>

	<tr>
	<td colspan=3>
	&nbsp;
	</td>
	</tr>

	<tr>
	<td colspan=3>
	<span class=smallnote>
	Use the following if you want the custom field to be a "normal" dropdown.
	<br>Create a pipe seperated list of values as shown below.
	<br>No individiual value should be longer than the length of your custom field.
	<br>Don't use commas, &gt;, or &lt; characters in the list of values.
	<br>
	"version 1.0|Version 1.1|Version 1.2"
	</span>
	</td>
	</tr>


	<tr>
	<td colspan=2>
	<br>
	<div  class=lbl >Normal Dropdown Values:</div><p>
	<textarea runat="server" class=txt id="vals" rows=4 cols=80></textarea></td>
	<td runat="server" class=err id="vals_err">&nbsp;</td>
	</tr>

	<tr>
	<td colspan=3>
	<span class=smallnote>
	Controls what order the custom fields display on the page.
	</span>
	</td>
	</tr>

	<tr>
	<td colspan=3>
	&nbsp;
	</td>
	</tr>

	<tr>
	<td class=lbl>Sort Sequence:</td>
	<td><input runat="server" type=text class=txt id="sort_seq" maxlength=2 size=2></td>
	<td runat="server" class=err id="sort_seq_err">&nbsp;</td>
	</tr>


	<tr><td colspan=3 align=left>
	<span runat="server" class=err id="msg">&nbsp;</span>
	</td></tr>

	<tr>
	<td colspan=2 align=center>
	<input runat="server" class=btn type=submit id="sub" value="Update" OnServerClick="on_update">
	<td>&nbsp</td>
	</td>
	</tr>

	</table>
</form>

</td></tr></table></div>
<% Response.Write(Application["custom_footer"]); %></body>
</html>



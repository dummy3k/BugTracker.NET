<%@ Page language="C#"%>
<!--
Copyright 2002-2008 Corey Trager
Distributed under the terms of the GNU General Public License
-->
<!-- #include file = "inc.aspx" -->

<script language="C#" runat="server">

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

	msg.InnerText = "";

	if (!IsPostBack)
	{
		datatype.Items.Insert(0, new ListItem("char", "char"));
		datatype.Items.Insert(0, new ListItem("datetime", "datetime"));
		datatype.Items.Insert(0, new ListItem("decimal", "decimal"));
		datatype.Items.Insert(0, new ListItem("int", "int"));
		datatype.Items.Insert(0, new ListItem("nchar", "nchar"));
		datatype.Items.Insert(0, new ListItem("nvarchar", "nvarchar"));
		datatype.Items.Insert(0, new ListItem("varchar", "varchar"));

		dropdown_type.Items.Insert(0, new ListItem("not a dropdown",""));
		dropdown_type.Items.Insert(1, new ListItem("normal","normal"));
		dropdown_type.Items.Insert(2, new ListItem("users","users"));

		sort_seq.Value = "1";

	}

}


///////////////////////////////////////////////////////////////////////
Boolean validate()
{

	Boolean good = true;
	if (name.Value == "")
	{
		good = false;
		name_err.InnerText = "Field name is required.";
	}
	else
	{
		name_err.InnerText = "";
	}


	if (length.Value == "")
	{
		if (datatype.SelectedItem.Value == "int"
		|| datatype.SelectedItem.Value == "datetime")
		{
			length_err.InnerText = "";
		}
		else
		{
			good = false;
			length_err.InnerText = "Length or Precision is required for this datatype.";
		}
	}
	else
	{
		if (datatype.SelectedItem.Value == "int" || datatype.SelectedItem.Value == "datetime")
		{
			good = false;
			length_err.InnerText = "Length or Precision not allowed for this datatype.";
		}
		else
		{
			length_err.InnerText = "";
		}
	}


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


	default_err.InnerText = "";
	if (required.Checked && default_text.Value == "")
	{
		if (default_text.Value == "")
		{
			good = false;
			default_err.InnerText = "If \"Required\" is checked, then Default is required.";
		}
	}


	return good;
}

///////////////////////////////////////////////////////////////////////
void on_update (Object sender, EventArgs e)
{

	Boolean good = validate();

	if (good)
	{
		sql = "alter table bugs add [$nm] $dt $ln $null $df";
		sql = sql.Replace("$nm", name.Value);
		sql = sql.Replace("$dt", datatype.SelectedItem.Value);
		sql = sql.Replace("$ln", length.Value);

		if (default_text.Value != "")
		{
			sql = sql.Replace("$df", "DEFAULT " + default_text.Value);
		}
		else
		{
			sql = sql.Replace("$df", "");
		}


		if (required.Checked)
		{
			sql = sql.Replace("$null", "NOT NULL");
		}
		else
		{
			sql = sql.Replace("$null", "NULL");
		}

		bool alter_table_worked = false;
		try
		{
			dbutil.execute_nonquery(sql);
			alter_table_worked = true;
		}
		catch (Exception e2)
		{
			msg.InnerHtml = "The generated SQL was invalid:<br><br>SQL:&nbsp;" + sql + "<br><br>Error:&nbsp;" + e2.Message;
			alter_table_worked = false;
		}

		if (alter_table_worked)
		{
			sql = @"declare @colorder int

				select @colorder = sc.colorder
				from syscolumns sc
				inner join sysobjects so on sc.id = so.id
				where so.name = 'bugs'
				and sc.name = '$nm'

				insert into custom_col_metadata
				(ccm_colorder, ccm_dropdown_vals, ccm_sort_seq, ccm_dropdown_type)
				values(@colorder, '$v', $ss, '$dt')";


			sql = sql.Replace("$nm", name.Value);
			sql = sql.Replace("$v", vals.Value.Replace("'", "''"));
			sql = sql.Replace("$ss", sort_seq.Value);
			sql = sql.Replace("$dt", dropdown_type.SelectedItem.Value.Replace("'", "''"));

			dbutil.execute_nonquery(sql);
			Server.Transfer ("customfields.aspx");
		}

	}
	else
	{
		msg.InnerText = "Custom field was not created.";
	}

}

</script>

<html>
<head>
<title id="titl" runat="server">btnet add custom field</title>
<link rel="StyleSheet" href="btnet.css" type="text/css">
</head>
<body>
<% security.write_menu(Response, "admin"); %>


<div class=align><table border=0><tr><td>
<a href=customfields.aspx>back to custom fields</a>
<form class=frm runat="server">
	<table border=0 width=640>

	<tr>
	<td colspan=3>
	<span class=smallnote>Don't use single quotes, &gt;, or &lt; characters in the Field Name.</span>
	</td>
	</tr>

	<tr>
	<td class=lbl>Field Name:</td>
	<td><input runat="server" type=text class=txt id="name" maxlength=30 size=30></td>
	<td runat="server" class=err id="name_err">&nbsp;</td>
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
	<span class=smallnote>For "user" dropdown, select "int"</span>
	</td>
	</tr>

	<tr>
	<td class=lbl>Datatype:</td>
	<td>
		<asp:DropDownList id="datatype" runat="server">
		</asp:DropDownList>
	</td>
	<td>&nbsp;</td>
	</tr>

	<tr>
	<td colspan=3>
	<span class=smallnote>
	<br><br>For char, varchar, etc, specify as (NNN).&nbsp;&nbsp;Don't forget the parenthesis.<br><br>
	For decimal specify as (A,B) where A is the total number of digits and B is the number of those digits to the right of decimal point.&nbsp;&nbsp;Don't forget the parenthesis.<br><br>
	</span>
	</td>
	</tr>

	<tr>
	<td class=lbl>Length/Precision:</td>
	<td><input runat="server" type=text class=txt id="length" maxlength=6 size=6></td>
	<td nowrap runat="server" class=err id="length_err">&nbsp;</td>
	</tr>

	<tr>
	<td colspan=3>
	<span class=smallnote>
	<br><br>If you specify required, you must supply a default.&nbsp;&nbsp;Don't forget the parenthesis.
	</span>
	</td>
	</tr>

	<tr>
	<td class=lbl>Required (NULL or NOT NULL):</td>
	<td><asp:checkbox runat="server" class=txt id="required"/></td>
	<td>&nbsp</td>
	</tr>

	<tr>
	<td class=lbl>Default:</td>
	<td><input runat="server" type=text class=txt id="default_text" maxlength=30 size=30></td>
	<td nowrap runat="server" class=err id="default_err">&nbsp;</td>
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
	&nbsp;
	</td>
	</tr>

	<tr>
	<td colspan=3>
	<span class=smallnote>
	Controls what order the custom fields display on the page.
	</span>
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
	<input runat="server" class=btn type=submit id="sub" value="Create" OnServerClick="on_update">
	<td>&nbsp</td>
	</td>
	</tr>
	</td></tr></table>
</form>
</td></tr></table></div>
<% Response.Write(Application["custom_footer"]); %></body>
</html>



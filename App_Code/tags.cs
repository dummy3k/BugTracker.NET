/*
Copyright 2002-2008 Corey Trager
Distributed under the terms of the GNU General Public License
*/

using System;
using System.Web;
using System.Data;
using System.IO;
using System.Text;
using System.Data.SqlClient;
using System.Collections.Generic;

namespace btnet
{
	public class Tags
	{

		public static string normalize_tag(string s)
		{
			// Standardize the lower/upper case.  Initial cap, then the rest lower.
			string s2 = s.Trim().ToUpper();
			if (s2.Length > 1)
			{
				s2 = s2[0] + s2.Substring(1).ToLower();
			}
			return s2;
		}

		public static void threadproc_tags(object obj)
		{
			System.Web.HttpApplicationState app = (System.Web.HttpApplicationState)obj;

			SortedDictionary<string,List<int>> tags = new SortedDictionary<string,List<int>>();

			// update the cache
			DbUtil dbutil = new DbUtil();
			DataSet ds = dbutil.get_dataset("select bg_id, bg_tags from bugs where isnull(bg_tags,'') <> ''");

			foreach (DataRow dr in ds.Tables[0].Rows)
			{
				string[] labels = btnet.Util.split_string_using_commas((string) dr[1]);

				// for each tag label, build a list of bugids that have that label
				for (int i = 0; i < labels.Length; i++)
				{

					string label = normalize_tag(labels[i]);

					if (label != "")
					{
						if (!tags.ContainsKey(label))
						{
							tags[label] = new List<int>();
						}

						tags[label].Add((int)dr[0]);
					}
				}
			}

			app["tags"] = tags;

		}

		public static void index_tags(System.Web.HttpApplicationState app)
		{
			System.Threading.Thread thread = new System.Threading.Thread(threadproc_tags);
			thread.Start(app);
		}

		public static string build_filter_clause(System.Web.HttpApplicationState app, string selected_labels)
		{
			string[] labels = btnet.Util.split_string_using_commas(selected_labels);

			SortedDictionary<string, List<int>> tags = (SortedDictionary<string, List<int>>) app["tags"];

			StringBuilder sb = new StringBuilder();
			sb.Append(" and id in (");

			bool first_time = true;

			// loop through all the tags entered by the user, building a list of
			// bug ids that contain ANY of the tags.
			for (int i = 0; i < labels.Length; i++)
			{
				string label = normalize_tag(labels[i]);

				if (tags.ContainsKey(label))
				{
					List<int> ids = tags[label];

					for (int j = 0; j < ids.Count; j++)
					{
						if (first_time)
						{
							first_time = false;
						}
						else
						{
							sb.Append(",");
						}

						sb.Append(Convert.ToString(ids[j]));

					} // end of loop through ids
				}
			} // end of loop through lables


			sb.Append(")");

			// filter the list so that it only displays bugs that have ANY of the entered tags
			return sb.ToString();

		}
	}

}



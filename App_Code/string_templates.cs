using System;
using System.Collections.Generic;
using System.Web;
using Antlr.StringTemplate;
using System.Text;
using System.Diagnostics;

namespace btnet
{
    public class StringTemplates
    {
        private StringTemplateGroup mI18N;
        private StringTemplateGroup mCommon;

        string mLanguage;
        public String Language
        {
            get
            {
                return mLanguage;
            }
            private set
            {
                mLanguage = value;
            }
        }

        public StringTemplates()
        {
            Init("en");
        }

        public StringTemplates(HttpRequest Request)
        {
            Init(Request["lang"]);
        }

        private void Init(String language) {
            if (language == null)
            {
                language = "en";
            }
            language = language.ToLower();
            this.Language = language;

            String[] directories = new String[] {
                @"stringtemplates",
                System.IO.Path.Combine(@"stringtemplates", language)
            };
            CommonGroupLoader groupLoader = new CommonGroupLoader(
                new DefaultGroupFactory(), null, Encoding.UTF8, directories);
            StringTemplateGroup.RegisterGroupLoader(groupLoader);

            mI18N = StringTemplateGroup.LoadGroup("templates");

            //StringTemplateGroup commonOneFile = StringTemplateGroup.LoadGroup("common");
            StringTemplateGroup commonOneFile = groupLoader.LoadGroup("common", mI18N, typeof(Antlr.StringTemplate.Language.DefaultTemplateLexer));
            commonOneFile.SuperGroup = mI18N;

            mCommon = new StringTemplateGroup("common", @"stringtemplates\common");
            mCommon.SuperGroup = commonOneFile;
        }

        public string getI18N(string name)
        {
            return mI18N.GetInstanceOf(name).ToString();
        }

        public StringTemplateGroup Common
        {
            get
            {
                return mCommon;
            }
        }

        public StringTemplateGroup I18N
        {
            get
            {
                return mI18N;
            }
        }
    }
}

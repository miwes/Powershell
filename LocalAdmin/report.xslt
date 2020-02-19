<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0">
  <xsl:output method="html" encoding="utf-8"/>
  <xsl:variable name="smallcase" select="'abcdefghijklmnopqrstuvwxyz'" />
  <xsl:variable name="uppercase" select="'ABCDEFGHIJKLMNOPQRSTUVWXYZ'" />
  <xsl:template match="/Report">
    <html>
      <head>
        <title>Report skupin</title>
        <style type="text/css">
          table
          {
          Margin: 1px 1px 1px 4px;
          Border: 1px solid rgb(190, 190, 190);
          Font-Family: Tahoma;
          Font-Size: 10pt;
          Background-Color: rgb(252, 252, 252);
          border-collapse: collapse;
          }
          tr:hover td
          {
          Background-Color: rgb(0, 150, 220);
          Color: rgb(255, 255, 255);
          }
          tr:nth-child(even)
          {
          Background-Color: rgb(222, 242, 242);
          }
          th
          {
          border: 1px solid;
          Text-Align: center;
          Padding: 4px 4px 4px 4px;
          Color: Black;
          }
          td
          {
          border: 1px solid;
          Vertical-Align: Top;
          Padding: 1px 4px 4px 4px;
          }
          H1
          {
          Font-Family: Tahoma;
          Font-Size: 12pt;
          }
          H2
          {
          Font-Family: Tahoma;
          Font-Size: 10pt;
          }
        </style>
      </head>
      <body>
        <h1>
          Report lokální skupiny:  <xsl:value-of select="@Group" />
        </h1>
        <hr/>
        <xsl:for-each select="Server">
        <H2>
          <xsl:value-of select="translate(@Name, $smallcase, $uppercase)" />
        </H2>
        <table>
          <tr>
            <th>
              User
            </th>
            <th>
              Type
            </th>
            <th>
              Path
            </th>
            <th>
              Description
            </th>
          </tr>
          <xsl:for-each select="Name">
          <tr>
            <td>
              <xsl:value-of select="@Value" />
            </td>
            <td>
              <xsl:value-of select="Type" />
            </td>
            <td>
              <xsl:value-of select="Domain" />
            </td>
            <td>
              <xsl:value-of select="Description" />
            </td>
          </tr>
          </xsl:for-each>
        </table>
        <br />
      </xsl:for-each>
   </body>
  </html>
  </xsl:template>
</xsl:stylesheet>

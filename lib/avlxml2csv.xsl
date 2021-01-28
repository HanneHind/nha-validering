<?xml version="1.0"?>

<xsl:stylesheet version="1.0" 
				xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:nha="http://www.arkivverket.no/standarder/nha/avlxml">
<xsl:output method="text" encoding="UTF-8"/>

<xsl:template match="/nha:avlxml">
	<xsl:for-each select="nha:pasientjournal">
			<xsl:value-of select="nha:journalidentifikator"/>
			<xsl:text>;</xsl:text>
			<xsl:value-of select="nha:fanearkidentifikator"/>
			<xsl:text>;</xsl:text>
			<xsl:value-of select="substring-after(substring-after(nha:lagringsenhet,':'),':')"/>
			<xsl:text>;</xsl:text>
			<xsl:value-of select="nha:fodselsnummer"/>
			<xsl:text>;</xsl:text>
			<xsl:value-of select="nha:fodtdato"/>
			<xsl:text>;</xsl:text>
			<xsl:value-of select="nha:morsdato"/>
			<xsl:text>;</xsl:text>
			<xsl:value-of select="nha:sistekontakt"/>
			<xsl:text>;</xsl:text>
			<xsl:value-of select="nha:sikkermors"/>
			<xsl:text>&#10;</xsl:text>
	</xsl:for-each>
</xsl:template>

</xsl:stylesheet>

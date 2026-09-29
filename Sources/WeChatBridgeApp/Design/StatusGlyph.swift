import AppKit

/// The monochrome menu-bar version of the app icon.
enum StatusGlyph {
    private static let size = NSSize(width: 30, height: 22)

    /// `image` with a red alert badge baked in. See `imageWithAlert`.
    private static let alertPNG = """
        iVBORw0KGgoAAAANSUhEUgAAADwAAAAsCAYAAAA5KtvpAAAJEklEQVR4nO2aZ2hU
        SxTH77obTbD3Lti7Rv2gEkURPzxFrGBFP4kNFQuKoCioH8SCiIIgNhAb9tieIhqN
        D4OiRixYsWEHRZ+assnL4xf2H47Xu7s3m/Aa70C4s3Nnzsz/nDNzyo3j/E//03+K
        AmVmEAgEKlSoUIEnv4sipHfqh/6IkPNvo0AgEAhGKJH5oVAohJCcf4OGQ6FQqKCg
        oEC/a9SoUaNz586dU1NTU1u3bt26YcOGDatUqVIFoeTl5eV9/Pjx47Nnz57dvXv3
        7q1bt249evTokeYiMKzhH6n1YDAYlHnyHDp06NC9e/fuffv27dsinxQOh8M3bty4
        sXTp0qUIxwrR+SdRyGxowoQJE9CUBVJYWFgYNlRgyPbZOWh/+/bt25s3b94cvpj4
        32XmnmDbtWvX7sKFCxe0YQHCHP1qmLESjvq+fv36de7cuXO1XqL3QrlQMLL4uHHj
        xn3//v27zJJN+wUZC7wFfvDgwYNa72/RdDCy+Pz58+dbrZYVqBfw/Pz8fNoXL168
        aO+JeHt0u70ym/GUKVOmCGh5aDUWCfSBAwcO+NGyBVqmYxCMTO7Vq1cvpF/ac1oe
        oKdOnTrVCj4a2MqVK1euVatWrYRBByKMmHz//v37XmYsIcQ6y3ZMaYQFP8Z/+PDh
        Q82aNWu6NWl/p6SkpNy8efPm+/fv3/fu3bs3fUlJSUmlAhyKSHTBggUL2IC9VGJt
        0g023phYpDUXL1682EvLMvWOHTt21JwvX7586dmzZ89SgQ5EJJecnJz88uXLl+6N
        WiDHjx8/vmXLli1Pnz59at/ZZ3p6evqOHTt2KDDxq2mtee/evXvuvVnAuEnGavzn
        z58/d+/evbtv0KGIJEePHj3abcoK+jljRFh2zrlz585pPGNycnJyBg0aNEhjqlWr
        Vu3q1atXS6tpqGvXrl0tSNvu0KFDB43TXgljO3Xq1MkX6FAE8K5du3ZZ07Lt3bt3
        7xazSpUqVaLdpUuXLjaY2Lp161b6K1asWBFrod23b9++pQEsXpMmTZpk9wZY+NJu
        3759e2s1As2ZVtia5AG6RHJKCEgC3FIV3blz547aaJvnq1evXn379u2bNnX79u3b
        PBU+0sb0AQFP+h2fpI0rM5OVuX0wPHmPQOvWrVs3IyMjg5A1HA6H3aCLQWli7dq1
        azdq1KiR7bNtNMXTMkLDVatWrUofv9PS0tJ4srjGYJpsiM3Sb2Ntad0Nlr46derU
        oY3gGNeiRYsW06dPn75nz549R44cOaJx1rswDgwEMU2aNGnCvn5yb9Jms2bNmnEG
        dW69LpN58+bN0zykSNonk9IlQsCiMW3btm37/Pnz5/HMWAKgnZubm8tz8+bNm+HR
        o0ePHvv27dunvfnhxfPJkydP6tevXx8eAh0QYAAimYcPHz7EoVvJuQmQ+EqCE86p
        xto5ZFTw7NatWzdMHlN//PjxY25tblS0jwZbtWrVimNUr169esxjs2yORGXMmDFj
        Zs2aNWvJkiVLxFdHL152JT4PHjx4gJ/+9OnTp5LxNnJ5/fr1ay8NuzUd7be93U+c
        OHFi2LBhwxQNRSNu8hEjRow4e/bsWeZhrgQWuD/tJZGILxy5/LKzs7M5dp5mffny
        5cvujXuBdm9Arov24cOHD2PKlj9CDXmQW0sDBgwYgLYzMzMzbbiZKOXl5eXxRPA/
        AJaNr1y5cqWVjh+yYGfPnj3b8rSVkmgkYSgelmbLCjY/Mh9+P5m/OuRX/ZqPzI32
        2LFjx8IjkQKfBE5IGQusigjxfLoF67gwlpA2ydnzm/9qzMKFCxcyV4EBvKzW7KIy
        Z2leG2nTpk0bbmgvgbsrJX7Apqenp7uxeQLmZvVzUQjspUuXLmnjXkm5AHndqir5
        RhO0tSC9I86+du3atVhgjx07diwmWLdpLV++fLll4EUyq4EDBw7UXIEdNWrUqFWr
        Vq3q169fP8u3adOmTeFNJUXhKcQ4y9MN/Pr169dnzJgxQ5ch7swKJSGwkNXQ0aNH
        j7oXdoPFb2u8QE2cOHGiHat8FbeHX1Q/Zd7iRR3HOXXq1Cm7lsyX0HXIkCFDHBeR
        HtrsTGAPHTp0SGOCfu8Ra3qnT58+7Za8V0KhcylB8Z7shc2gaZtEUKnEXZDHshYX
        pW56W9yDD8HJtGnTplHgh4fCVZs8COz+/fv3e2HwRZIOl5BCQwtam1qzZs0aN+A5
        c+bMscIZPHjwYMXqZDPqP3/+/Hn6iY3FU3zXrl27lqoHY/gNQK2j9BBrEFhrLQlV
        PQMRMyUKevPmzRt7VuxCGzZs2GA3IuLWJmJyp3jExWiCNJLop2XLli0Vh4snronA
        X4UI3iuLEx97hnfu3LmzTGCthimdCKwiLC2ESZ45c+aMHe9FbvdjSfeEEgaSE4TA
        cRBYtE6fmwcx9ooVK1bot94VpaUWuf+ceCRJTp48eTIL20yFfLNPnz59MDlCUbRh
        gUkAXgEImyJOpj1y5MiR9qKiWknpBkHas8nHOPn3aFFbSW7sAbbIgI6rft2wZEXc
        yHyF6N+/f3+AkoFQOXSbLVRoyA0Y4TVo0KDBpk2bNkk4w4cPH45vhR+mjkUJBJkT
        4OGPAKxQtWaxJuJosijWe2mGa550jjNppazbkrOEIFTOiXWGNIdN8hVR2uNzK67H
        ujwbcKg4F+vY/KDN33+PqWVPknRxC6qCuLWo9urVq1efPHnypADH2hiZEN+IAbJ+
        /fr11atXr674WfeENed169at8+NTywzYfV5sFGVJfaRzlGXteEtYAJ9aqYvxmZSI
        idLPlStXrugcywsItPWr8TKucgHs54OVNeGMCNmP3SJMn2yKMioXHmDcPt2C3bZt
        2zavNcoKOOCUA6lERJs4mduWck5WVlbWixcvXiAwjga3OWDlYkSAFCjG4pIaN27c
        GFelwpwfwCU/fs10nF+K640/UbkAhlSChTjzM2fOnEnZBjcTbQ7nlO/O/J+IrUPR
        jyVw1q0wfYP+KwBH+6cXfDXaQsO4G94rzn737t07nuPHjx+/bNmyZdSUAQdIvnCQ
        vPvV8A+gk1McJzfnp3eB37LLHW8xKckvzcdq4uyNGzdupMKJlSxatGgR/Yn8w0tR
        1m9RL6s/Abrl+xZ3oAL+AAAAAElFTkSuQmCC
        """
    private static let templatePNG = """
        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
        yXoTrYsAAAAASUVORK5CYII=
        """

    static var image: NSImage {
        let data = Data(base64Encoded: templatePNG, options: .ignoreUnknownCharacters)
        let image = data.flatMap(NSImage.init(data:)) ?? NSImage(size: size)
        image.size = size
        image.isTemplate = true
        return image
    }

    /// The glyph with a red badge, for a forward that failed before the user
    /// saw it. A silent failure reads as a broken app, and the menu bar icon is
    /// the one thing in this app that is always on screen.
    ///
    /// Pre-rendered rather than composited at runtime: the plain glyph is a
    /// template image, and drawing a colour badge onto one through
    /// `lockFocus` left the badge visible and the glyph beneath it not — the
    /// bar rendered a bare red dot, with nothing to say which app was asking.
    /// One PNG with both shapes baked in keeps the glyph intact.
    ///
    /// The badge sits in the artwork's own empty corner — the 10×10 pt square
    /// at the bottom right holds two alpha pixels — so the mark covers none of
    /// the shape it is attached to.
    static var imageWithAlert: NSImage {
        let data = Data(base64Encoded: alertPNG, options: .ignoreUnknownCharacters)
        let image = data.flatMap(NSImage.init(data:)) ?? Self.image
        image.size = size
        image.isTemplate = false
        return image
    }
}

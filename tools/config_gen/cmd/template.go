package cmd

import (
	"github.com/spf13/cobra"
)

var startCmd = &cobra.Command{
	Use:   "run",
	Short: "Generate install configuration",
	Run: func(cmd *cobra.Command, args []string) {
		setup()
	},
}

func setup() {

}

func init() {
	rootCmd.AddCommand(startCmd)
}
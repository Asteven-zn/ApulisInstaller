package cmd

import (
	"os"

	"github.com/spf13/cobra"
)

var rootCmd = &cobra.Command{
	Use:               "config_gen",
	SilenceUsage:      true,
	DisableAutoGenTag: true,
	PersistentPreRunE: func(cmd *cobra.Command, args []string) error {
		return nil
	},
}

func Execute() {
	if err := rootCmd.Execute(); err != nil {
		os.Exit(-1)
	}
}
